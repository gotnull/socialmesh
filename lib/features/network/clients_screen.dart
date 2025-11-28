import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _sortBy = 'Signal Strength (low first)';

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Clients'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showSortOptions,
            ),
          ],
        ),
        body: Column(
          children: [
            // Sort dropdown
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: _showSortOptions,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 8),
                      Text(_sortBy),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Clients list
            Expanded(
              child: nodes.isEmpty
                  ? const Center(
                      child: Text(
                        'No clients detected',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: nodes.length,
                      itemBuilder: (context, index) {
                        final node = nodes.values.elementAt(index);
                        return _ClientCard(
                          macAddress: node.nodeNum
                              .toRadixString(16)
                              .padLeft(12, '0')
                              .toUpperCase(),
                          rssi: node.snr?.toInt() ?? -50,
                          vendor: 'Apple',
                          channel: 1,
                          bssid: 'COUNTRYLINK3177',
                          apAlias: node.displayName,
                          utilization: 1.3,
                          phyTypes: 'b/g/n',
                          retryRate: 27,
                          signalHistory: [
                            -45,
                            -48,
                            -52,
                            -50,
                            -47,
                            -49,
                            -51,
                            -53,
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Signal Strength (low first)'),
              trailing: _sortBy == 'Signal Strength (low first)'
                  ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                  : null,
              onTap: () {
                setState(() => _sortBy = 'Signal Strength (low first)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Signal Strength (high first)'),
              trailing: _sortBy == 'Signal Strength (high first)'
                  ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                  : null,
              onTap: () {
                setState(() => _sortBy = 'Signal Strength (high first)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('MAC Address'),
              trailing: _sortBy == 'MAC Address'
                  ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                  : null,
              onTap: () {
                setState(() => _sortBy = 'MAC Address');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final String macAddress;
  final int rssi;
  final String vendor;
  final int channel;
  final String bssid;
  final String apAlias;
  final double utilization;
  final String phyTypes;
  final int retryRate;
  final List<int> signalHistory;

  const _ClientCard({
    required this.macAddress,
    required this.rssi,
    required this.vendor,
    required this.channel,
    required this.bssid,
    required this.apAlias,
    required this.utilization,
    required this.phyTypes,
    required this.retryRate,
    required this.signalHistory,
  });

  Color get _signalColor {
    if (rssi >= -50) return AppTheme.successGreen;
    if (rssi >= -60) return AppTheme.warningYellow;
    if (rssi >= -70) return AppTheme.accentOrange;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _signalColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with MAC and signal
          Row(
            children: [
              Expanded(
                child: Text(
                  macAddress,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _signalColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rssi dBm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _signalColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),

          const SizedBox(height: 16),

          // Vendor and Channel row
          Row(
            children: [
              _InfoChip(label: 'Vendor', value: vendor),
              const SizedBox(width: 12),
              _InfoChip(label: 'Channel', value: '$channel'),
            ],
          ),

          const SizedBox(height: 12),

          // BSSID Info
          Row(
            children: [
              const Text(
                'Conn. BSSID',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
              const SizedBox(width: 8),
              Text(
                bssid,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // AP Alias
          Row(
            children: [
              const Text(
                'Conn. AP Alias',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
              const SizedBox(width: 8),
              Text(
                apAlias,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatItem(label: 'Utilization', value: '$utilization%'),
              ),
              Expanded(
                child: _StatItem(label: 'PHY Types', value: phyTypes),
              ),
              Expanded(
                child: _StatItem(label: 'Retry Rate', value: '$retryRate%'),
              ),
            ],
          ),

          if (signalHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.darkBorder, height: 1),
            const SizedBox(height: 16),

            // Signal strength chart
            const Text(
              'Signal Strength Live',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: _SignalStrengthChart(
                data: signalHistory,
                color: _signalColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SignalStrengthChart extends StatelessWidget {
  final List<int> data;
  final Color color;

  const _SignalStrengthChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 2,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == 0 || value == data.length - 1) {
                  final time = DateTime.now().subtract(
                    Duration(minutes: (data.length - 1 - value.toInt())),
                  );
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat('HH:mm').format(time),
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 9,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: data.reduce((a, b) => a < b ? a : b).toDouble() - 5,
        maxY: data.reduce((a, b) => a > b ? a : b).toDouble() + 5,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (index) => FlSpot(index.toDouble(), data[index].toDouble()),
            ),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
