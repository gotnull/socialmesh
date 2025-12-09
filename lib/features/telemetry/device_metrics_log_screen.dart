import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Device metrics history screen with filtering and graph views
class DeviceMetricsLogScreen extends ConsumerStatefulWidget {
  const DeviceMetricsLogScreen({super.key});

  @override
  ConsumerState<DeviceMetricsLogScreen> createState() =>
      _DeviceMetricsLogScreenState();
}

class _DeviceMetricsLogScreenState
    extends ConsumerState<DeviceMetricsLogScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showGraph = false;
  _GraphMetric _selectedMetric = _GraphMetric.battery;

  List<DeviceMetricsLog> _filterLogs(List<DeviceMetricsLog> logs) {
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
    final logsAsync = ref.watch(deviceMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device History'),
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
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    Icons.battery_unknown,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hasActiveFilters
                        ? 'No metrics match filters'
                        : 'No device history',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
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
            return _DeviceGraphView(
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

              return _DeviceMetricsCard(log: log, nodeName: nodeName);
            },
          );
        },
      ),
    );
  }
}

enum _GraphMetric {
  battery('Battery', '%', Icons.battery_full),
  voltage('Voltage', 'V', Icons.bolt),
  channelUtil('Channel', '%', Icons.signal_cellular_alt),
  airUtil('Air Util', '%', Icons.wifi);

  final String label;
  final String unit;
  final IconData icon;

  const _GraphMetric(this.label, this.unit, this.icon);
}

class _DeviceGraphView extends StatelessWidget {
  final List<DeviceMetricsLog> logs;
  final _GraphMetric selectedMetric;
  final ValueChanged<_GraphMetric> onMetricChanged;

  const _DeviceGraphView({
    required this.logs,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Prepare data points sorted by time
    final sortedLogs = List<DeviceMetricsLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = <FlSpot>[];
    double? minY;
    double? maxY;

    for (int i = 0; i < sortedLogs.length; i++) {
      final log = sortedLogs[i];
      double? value;

      switch (selectedMetric) {
        case _GraphMetric.battery:
          value = log.batteryLevel?.toDouble();
        case _GraphMetric.voltage:
          value = log.voltage;
        case _GraphMetric.channelUtil:
          value = log.channelUtilization;
        case _GraphMetric.airUtil:
          value = log.airUtilTx;
      }

      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
        minY = minY == null ? value : math.min(minY, value);
        maxY = maxY == null ? value : math.max(maxY, value);
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selectedMetric.icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No ${selectedMetric.label.toLowerCase()} data',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // Set appropriate Y range based on metric type
    double finalMinY, finalMaxY;
    switch (selectedMetric) {
      case _GraphMetric.battery:
      case _GraphMetric.channelUtil:
      case _GraphMetric.airUtil:
        finalMinY = 0;
        finalMaxY = 100;
      case _GraphMetric.voltage:
        final yPadding = ((maxY ?? 0) - (minY ?? 0)) * 0.1;
        finalMinY = (minY ?? 0) - yPadding;
        finalMaxY = (maxY ?? 0) + yPadding;
    }

    return Column(
      children: [
        // Metric selector
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

        // Stats summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StatsRow(logs: sortedLogs, metric: selectedMetric),
        ),

        const SizedBox(height: 16),

        // Graph
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((finalMaxY - finalMinY) / 4).clamp(
                    1,
                    100,
                  ),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.darkBorder.withValues(alpha: 0.5),
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
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary,
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
                      interval: ((finalMaxY - finalMinY) / 4).clamp(1, 100),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(selectedMetric == _GraphMetric.voltage ? 2 : 0)}${selectedMetric.unit}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: finalMinY,
                maxY: finalMaxY,
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
                    getTooltipColor: (_) => AppTheme.darkCard,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.x.toInt();
                        final log = sortedLogs[index];
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(selectedMetric == _GraphMetric.voltage ? 2 : 0)}${selectedMetric.unit}\n${DateFormat('MMM d HH:mm').format(log.timestamp)}',
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
    );
  }

  Color _getMetricColor(_GraphMetric metric) {
    switch (metric) {
      case _GraphMetric.battery:
        return AccentColors.green;
      case _GraphMetric.voltage:
        return AppTheme.warningYellow;
      case _GraphMetric.channelUtil:
        return AppTheme.primaryBlue;
      case _GraphMetric.airUtil:
        return AppTheme.primaryMagenta;
    }
  }
}

class _StatsRow extends StatelessWidget {
  final List<DeviceMetricsLog> logs;
  final _GraphMetric metric;

  const _StatsRow({required this.logs, required this.metric});

  @override
  Widget build(BuildContext context) {
    final values = <double>[];
    for (final log in logs) {
      double? value;
      switch (metric) {
        case _GraphMetric.battery:
          value = log.batteryLevel?.toDouble();
        case _GraphMetric.voltage:
          value = log.voltage;
        case _GraphMetric.channelUtil:
          value = log.channelUtilization;
        case _GraphMetric.airUtil:
          value = log.airUtilTx;
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

    final decimals = metric == _GraphMetric.voltage ? 2 : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Current',
            value: '${current.toStringAsFixed(decimals)}${metric.unit}',
            color: Theme.of(context).colorScheme.primary,
          ),
          _StatItem(
            label: 'Avg',
            value: '${avg.toStringAsFixed(decimals)}${metric.unit}',
            color: AppTheme.textSecondary,
          ),
          _StatItem(
            label: 'Min',
            value: '${min.toStringAsFixed(decimals)}${metric.unit}',
            color: AccentColors.cyan,
          ),
          _StatItem(
            label: 'Max',
            value: '${max.toStringAsFixed(decimals)}${metric.unit}',
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

class _DeviceMetricsCard extends StatelessWidget {
  final DeviceMetricsLog log;
  final String nodeName;

  const _DeviceMetricsCard({required this.log, required this.nodeName});

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
                  Icons.memory,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
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

            // Battery indicator
            if (log.batteryLevel != null) ...[
              Row(
                children: [
                  Icon(
                    _getBatteryIcon(log.batteryLevel!),
                    size: 20,
                    color: _getBatteryColor(log.batteryLevel!),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: log.batteryLevel! / 100,
                        backgroundColor: AppTheme.darkSurface,
                        color: _getBatteryColor(log.batteryLevel!),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${log.batteryLevel}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _getBatteryColor(log.batteryLevel!),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Metrics
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (log.voltage != null)
                  _MetricChip(
                    icon: Icons.bolt,
                    label: 'Voltage',
                    value: '${log.voltage!.toStringAsFixed(2)}V',
                    color: AppTheme.warningYellow,
                  ),
                if (log.channelUtilization != null)
                  _MetricChip(
                    icon: Icons.signal_cellular_alt,
                    label: 'Channel',
                    value: '${log.channelUtilization!.toStringAsFixed(1)}%',
                    color: AppTheme.primaryBlue,
                  ),
                if (log.airUtilTx != null)
                  _MetricChip(
                    icon: Icons.wifi,
                    label: 'Air Util',
                    value: '${log.airUtilTx!.toStringAsFixed(1)}%',
                    color: AppTheme.primaryMagenta,
                  ),
                if (log.uptimeSeconds != null)
                  _MetricChip(
                    icon: Icons.timer,
                    label: 'Uptime',
                    value: _formatUptime(log.uptimeSeconds!),
                    color: AccentColors.green,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level <= 10) return Icons.battery_alert;
    if (level <= 20) return Icons.battery_1_bar;
    if (level <= 40) return Icons.battery_2_bar;
    if (level <= 60) return Icons.battery_4_bar;
    if (level <= 80) return Icons.battery_5_bar;
    return Icons.battery_full;
  }

  Color _getBatteryColor(int level) {
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
          const SizedBox(width: 6),
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
                ).textTheme.labelSmall?.copyWith(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
