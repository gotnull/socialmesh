import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../services/node_history_service.dart';

/// Chart type for node history visualization
enum NodeChartMetric {
  battery('Battery', '%', Icons.battery_std),
  connectivity('Connectivity', '', Icons.hub),
  channelUtil('Channel Util', '%', Icons.wifi_channel);

  final String label;
  final String unit;
  final IconData icon;

  const NodeChartMetric(this.label, this.unit, this.icon);
}

/// Widget displaying historical charts for a mesh node
class NodeHistoryCharts extends StatefulWidget {
  final List<NodeHistoryEntry> history;
  final Color accentColor;

  const NodeHistoryCharts({
    super.key,
    required this.history,
    required this.accentColor,
  });

  @override
  State<NodeHistoryCharts> createState() => _NodeHistoryChartsState();
}

class _NodeHistoryChartsState extends State<NodeHistoryCharts> {
  NodeChartMetric _selectedMetric = NodeChartMetric.battery;

  @override
  Widget build(BuildContext context) {
    if (widget.history.length < 2) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart, size: 40, color: context.textTertiary),
            SizedBox(height: 12),
            Text(
              'Need more data for charts',
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              '${widget.history.length}/2 data points',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric selector
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: NodeChartMetric.values.map((metric) {
                  final isSelected = metric == _selectedMetric;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            metric.icon,
                            size: 14,
                            color: isSelected
                                ? widget.accentColor
                                : context.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(metric.label),
                        ],
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedMetric = metric),
                      selectedColor: widget.accentColor.withValues(alpha: 0.2),
                      checkmarkColor: widget.accentColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? widget.accentColor
                            : context.textSecondary,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? widget.accentColor.withValues(alpha: 0.5)
                            : context.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Chart
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
              child: _buildChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = <FlSpot>[];
    final sortedHistory = List<NodeHistoryEntry>.from(widget.history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double? minY, maxY;

    for (var i = 0; i < sortedHistory.length; i++) {
      final entry = sortedHistory[i];
      double? value;

      switch (_selectedMetric) {
        case NodeChartMetric.battery:
          value = entry.batteryLevel?.toDouble();
          if (value != null && value > 100) value = 100; // Cap charging
        case NodeChartMetric.connectivity:
          // Combine neighbors + gateways as connectivity score
          value = (entry.neighborCount + entry.gatewayCount).toDouble();
        case NodeChartMetric.channelUtil:
          value = entry.channelUtil;
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
            Icon(_selectedMetric.icon, size: 32, color: context.textTertiary),
            SizedBox(height: 8),
            Text(
              'No ${_selectedMetric.label.toLowerCase()} data',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate Y range
    double finalMinY, finalMaxY;
    switch (_selectedMetric) {
      case NodeChartMetric.battery:
      case NodeChartMetric.channelUtil:
        finalMinY = 0;
        finalMaxY = 100;
      case NodeChartMetric.connectivity:
        finalMinY = 0;
        finalMaxY = math.max((maxY ?? 10) * 1.2, 10);
    }

    final Color lineColor;
    switch (_selectedMetric) {
      case NodeChartMetric.battery:
        final avg =
            spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length;
        lineColor = avg > 50
            ? AccentColors.green
            : avg > 20
            ? AppTheme.warningYellow
            : AppTheme.errorRed;
      case NodeChartMetric.connectivity:
        lineColor = widget.accentColor;
      case NodeChartMetric.channelUtil:
        final avg =
            spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length;
        lineColor = avg < 30
            ? AccentColors.green
            : avg < 60
            ? AppTheme.warningYellow
            : AppTheme.errorRed;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((finalMaxY - finalMinY) / 4).clamp(1, 100),
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
              reservedSize: 28,
              interval: math.max(1, spots.length / 5),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedHistory.length) {
                  return const SizedBox.shrink();
                }
                final entry = sortedHistory[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('HH:mm').format(entry.timestamp),
                    style: TextStyle(
                      fontSize: 9,
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
              reservedSize: 36,
              interval: ((finalMaxY - finalMinY) / 4).clamp(1, 100),
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(0)}${_selectedMetric.unit}',
                  style: TextStyle(
                    fontSize: 9,
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
        minY: finalMinY,
        maxY: finalMaxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.card,
            tooltipBorder: BorderSide(color: lineColor.withValues(alpha: 0.5)),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < sortedHistory.length) {
                  final entry = sortedHistory[index];
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(_selectedMetric == NodeChartMetric.connectivity ? 0 : 1)}${_selectedMetric.unit}\n${DateFormat('MMM d, HH:mm').format(entry.timestamp)}',
                    TextStyle(
                      color: lineColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length < 20,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: lineColor,
                    strokeWidth: 1,
                    strokeColor: context.card,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.3),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
