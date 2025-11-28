import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

class NetworkDetailsScreen extends ConsumerStatefulWidget {
  const NetworkDetailsScreen({super.key});

  @override
  ConsumerState<NetworkDetailsScreen> createState() =>
      _NetworkDetailsScreenState();
}

class _NetworkDetailsScreenState extends ConsumerState<NetworkDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Network Details'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          ],
        ),
        body: Column(
          children: [
            // Channel Selector Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 1; i <= 11; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ChannelPill(
                          label: '$i - ${i + 10}',
                          isSelected: i == 1,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Spectrum Chart
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const _SpectrumChart(),
            ),

            // Filter Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 20),
                    SizedBox(width: 8),
                    Text('Utilization (low first)'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Channels List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ChannelCard(
                    channelNumber: 1,
                    bssids: 5,
                    clients: 2,
                    utilization: 1.3,
                    networks: ['COUNTRYLINK3177', 'Aloha_5G'],
                  ),
                  _ChannelCard(
                    channelNumber: 6,
                    bssids: 12,
                    clients: 23,
                    utilization: 1.3,
                    networks: ['WiFi-6E', 'HomeNet', 'Guest'],
                  ),
                ],
              ),
            ),

            // Bottom Navigation
            Container(
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      icon: Icons.wifi,
                      label: 'Networks',
                      isSelected: true,
                      onTap: () {},
                    ),
                    _NavItem(
                      icon: Icons.router,
                      label: 'Channels',
                      isSelected: false,
                      onTap: () {},
                    ),
                    _NavItem(
                      icon: Icons.settings,
                      label: 'Settings',
                      isSelected: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelPill extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _ChannelPill({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryGreen.withValues(alpha: 0.3)
            : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SpectrumChart extends StatelessWidget {
  const _SpectrumChart();

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppTheme.darkBorder.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: AppTheme.darkBorder.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
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
              reservedSize: 30,
              interval: 2,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                );
                String text;
                switch (value.toInt()) {
                  case 1:
                    text = '1';
                    break;
                  case 6:
                    text = '6';
                    break;
                  case 11:
                    text = '11';
                    break;
                  default:
                    return Container();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(text, style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 32,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                );
                return Text('-${value.toInt()}', style: style);
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: 90,
        lineBarsData: [
          LineChartBarData(
            spots: _generateSpectrumData(),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [AppTheme.graphPurple, AppTheme.graphBlue],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.graphPurple.withValues(alpha: 0.3),
                  AppTheme.graphBlue.withValues(alpha: 0.1),
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

  List<FlSpot> _generateSpectrumData() {
    return [
      const FlSpot(0, 45),
      const FlSpot(1, 65),
      const FlSpot(2, 55),
      const FlSpot(3, 60),
      const FlSpot(4, 50),
      const FlSpot(5, 70),
      const FlSpot(6, 75),
      const FlSpot(7, 65),
      const FlSpot(8, 55),
      const FlSpot(9, 50),
      const FlSpot(10, 60),
      const FlSpot(11, 55),
    ];
  }
}

class _ChannelCard extends StatelessWidget {
  final int channelNumber;
  final int bssids;
  final int clients;
  final double utilization;
  final List<String> networks;

  const _ChannelCard({
    required this.channelNumber,
    required this.bssids,
    required this.clients,
    required this.utilization,
    required this.networks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CH $channelNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(label: '# of BSSIDs', value: '$bssids'),
              ),
              Expanded(
                child: _StatItem(label: '# of Clients', value: '$clients'),
              ),
              Expanded(
                child: _StatItem(label: 'Utilization', value: '$utilization%'),
              ),
            ],
          ),
          if (networks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Networks',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...networks.map(
              (network) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      network,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? AppTheme.primaryGreen
                    : AppTheme.textTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
