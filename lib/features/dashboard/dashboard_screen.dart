import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Get battery level from our own node
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final batteryLevel = myNode?.batteryLevel;

    final connectionState = connectionStateAsync.when(
      data: (state) => state,
      loading: () => transport.DeviceConnectionState.connecting,
      error: (error, stackTrace) => transport.DeviceConnectionState.error,
    );

    // Determine effective state: if auto-reconnect is in progress, show that
    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Meshtastic',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Battery indicator
          if (batteryLevel != null &&
              connectionState == transport.DeviceConnectionState.connected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getBatteryIcon(batteryLevel),
                    size: 20,
                    color: _getBatteryColor(batteryLevel),
                  ),
                  // Only show percentage text if not charging
                  if (batteryLevel <= 100) ...[
                    const SizedBox(width: 2),
                    Text(
                      '$batteryLevel%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getBatteryColor(batteryLevel),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color:
                  connectionState == transport.DeviceConnectionState.connected
                  ? AppTheme.primaryGreen
                  : isReconnecting
                  ? AppTheme.warningYellow
                  : AppTheme.textTertiary,
            ),
            onPressed: () {
              _showConnectionInfo(context, connectedDevice, connectionState);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: connectionState != transport.DeviceConnectionState.connected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isReconnecting) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _getConnectionStateText(
                        connectionState,
                        autoReconnectState,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      autoReconnectState == AutoReconnectState.scanning
                          ? 'Scanning for device...'
                          : 'Establishing connection...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      autoReconnectState == AutoReconnectState.failed
                          ? Icons.wifi_off
                          : Icons.bluetooth_disabled,
                      size: 64,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getConnectionStateText(
                        connectionState,
                        autoReconnectState,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (autoReconnectState == AutoReconnectState.failed) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Could not find saved device',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/scanner');
                      },
                      icon: const Icon(Icons.bluetooth_searching, size: 20),
                      label: const Text('Scan for Devices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Device card matching scanner design
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showConnectionInfo(
                        context,
                        connectedDevice,
                        connectionState,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.darkBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.router,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    connectedDevice?.name ?? 'Unknown Device',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    connectedDevice?.type ==
                                            transport.TransportType.ble
                                        ? 'Bluetooth'
                                        : 'USB',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textTertiary,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppTheme.textTertiary,
                              ),
                              onPressed: () => _disconnect(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.group_outlined,
                        label: 'Nodes',
                        value: nodes.length,
                        onTap: () => Navigator.of(context).pushNamed('/nodes'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Messages',
                        value: messages.length,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/messages'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Quick Actions Section
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                _ActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Messages',
                  subtitle: 'Send and receive messages',
                  onTap: () => Navigator.of(context).pushNamed('/messages'),
                ),

                _ActionCard(
                  icon: Icons.map_outlined,
                  title: 'Node Map',
                  subtitle: 'View nodes on a map',
                  onTap: () => Navigator.of(context).pushNamed('/map'),
                ),

                _ActionCard(
                  icon: Icons.group_outlined,
                  title: 'Nodes',
                  subtitle: 'View all discovered nodes',
                  onTap: () => Navigator.of(context).pushNamed('/nodes'),
                ),

                _ActionCard(
                  icon: Icons.wifi_tethering_outlined,
                  title: 'Channels',
                  subtitle: 'Manage communication channels',
                  onTap: () => Navigator.of(context).pushNamed('/channels'),
                ),

                _ActionCard(
                  icon: Icons.tune_outlined,
                  title: 'Device Config',
                  subtitle: 'Configure device role and settings',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/device-config'),
                ),

                const SizedBox(height: 32),

                // Signal Strength Live
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Signal Strength Live',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const _SignalStrengthChart(),
              ],
            ),
    );
  }

  IconData _getBatteryIcon(int level) {
    // Meshtastic uses 101 for charging, 100 for plugged in fully charged
    if (level > 100) return Icons.battery_charging_full;
    if (level >= 95) return Icons.battery_full;
    if (level >= 80) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    if (level >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AppTheme.primaryGreen; // Charging
    if (level >= 50) return AppTheme.primaryGreen;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  String _getConnectionStateText(
    transport.DeviceConnectionState state,
    AutoReconnectState autoReconnectState,
  ) {
    // If auto-reconnect is in progress, show that status
    if (autoReconnectState == AutoReconnectState.scanning) {
      return 'Reconnecting...';
    }
    if (autoReconnectState == AutoReconnectState.connecting) {
      return 'Reconnecting...';
    }

    switch (state) {
      case transport.DeviceConnectionState.connecting:
        return 'Connecting...';
      case transport.DeviceConnectionState.connected:
        return 'Connected';
      case transport.DeviceConnectionState.disconnecting:
        return 'Disconnecting...';
      case transport.DeviceConnectionState.error:
        return 'Connection Error';
      case transport.DeviceConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  void _showConnectionInfo(
    BuildContext context,
    transport.DeviceInfo? device,
    transport.DeviceConnectionState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Connection Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Zebra table
            _DeviceDetailsTable(device: device, state: state),
            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkBackground,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to disconnect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final protocol = ref.read(protocolServiceProvider);
      protocol.stop();

      final transport = ref.read(transportProvider);
      await transport.disconnect();

      ref.read(connectedDeviceProvider.notifier).state = null;

      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/scanner');
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalStrengthChart extends ConsumerStatefulWidget {
  const _SignalStrengthChart();

  @override
  ConsumerState<_SignalStrengthChart> createState() =>
      _SignalStrengthChartState();
}

class _SignalStrengthChartState extends ConsumerState<_SignalStrengthChart> {
  final List<_MultiSignalData> _signalHistory = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _addDataPoint();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _addDataPoint();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _addDataPoint() {
    final rssiAsync = ref.read(currentRssiProvider);
    final snrAsync = ref.read(currentSnrProvider);
    final channelUtilAsync = ref.read(currentChannelUtilProvider);
    final now = DateTime.now();

    final rssiValue = rssiAsync.valueOrNull?.toDouble() ?? -90.0;
    final snrValue = snrAsync.valueOrNull ?? 0.0;
    final channelUtilValue = channelUtilAsync.valueOrNull ?? 0.0;

    _signalHistory.add(
      _MultiSignalData(
        time: now,
        rssi: rssiValue,
        snr: snrValue,
        channelUtil: channelUtilValue,
      ),
    );
    if (_signalHistory.length > 30) _signalHistory.removeAt(0);
    if (mounted) setState(() {});
  }

  String _getSignalQuality(double rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Very Good';
    if (rssi >= -70) return 'Good';
    if (rssi >= -80) return 'Fair';
    if (rssi >= -90) return 'Weak';
    return 'Poor';
  }

  Color _getSignalColor(double rssi) {
    if (rssi >= -60) return AppTheme.primaryGreen;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final currentRssi = _signalHistory.isNotEmpty
        ? _signalHistory.last.rssi
        : -90.0;
    final currentSnr = _signalHistory.isNotEmpty
        ? _signalHistory.last.snr
        : 0.0;
    final currentChannelUtil = _signalHistory.isNotEmpty
        ? _signalHistory.last.channelUtil
        : 0.0;
    final hasData = _signalHistory.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // Header with current signal info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                // Signal indicator
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getSignalColor(currentRssi).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        color: _getSignalColor(currentRssi),
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currentRssi.toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getSignalColor(currentRssi),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Signal stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getSignalQuality(currentRssi),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _getSignalColor(currentRssi),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${currentRssi.toInt()} dBm',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Show all 3 metrics inline
                      Row(
                        children: [
                          _MetricChip(
                            label: 'SNR',
                            value: '${currentSnr.toStringAsFixed(1)} dB',
                            color: const Color(0xFF2196F3),
                            tooltip:
                                'Signal-to-Noise Ratio: Higher is better.\n'
                                'Good: > 10 dB, Fair: 0-10 dB, Poor: < 0 dB',
                          ),
                          const SizedBox(width: 8),
                          _MetricChip(
                            label: 'Ch Util',
                            value: '${currentChannelUtil.toStringAsFixed(1)}%',
                            color: const Color(0xFFFF9800),
                            tooltip:
                                'Channel Utilization: Airtime usage.\n'
                                'Low: < 25%, Moderate: 25-50%, High: > 50%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.errorRed.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.errorRed,
                          fontFamily: 'Inter',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _LegendItem(color: AppTheme.primaryGreen, label: 'RSSI (dBm)'),
                const SizedBox(width: 16),
                _LegendItem(color: const Color(0xFF2196F3), label: 'SNR (dB)'),
                const SizedBox(width: 16),
                _LegendItem(
                  color: const Color(0xFFFF9800),
                  label: 'Ch Util (%)',
                ),
              ],
            ),
          ),
          // Chart
          SizedBox(
            height: 180,
            child: hasData
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                    child: CustomPaint(
                      painter: _MultiLineChartPainter(_signalHistory),
                      child: Container(),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Waiting for signal data...',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, preferBelow: false, child: chip);
    }
    return chip;
  }
}

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
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textTertiary,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _MultiSignalData {
  final DateTime time;
  final double rssi;
  final double snr;
  final double channelUtil;

  _MultiSignalData({
    required this.time,
    required this.rssi,
    required this.snr,
    required this.channelUtil,
  });
}

class _MultiLineChartPainter extends CustomPainter {
  final List<_MultiSignalData> data;

  // Colors for each metric
  static const Color rssiColor = AppTheme.primaryGreen;
  static const Color snrColor = Color(0xFF2196F3);
  static const Color channelUtilColor = Color(0xFFFF9800);

  _MultiLineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftInset = 42.0;
    const bottomInset = 20.0;
    const topInset = 4.0;
    const rightInset = 40.0; // Extra space for right Y-axis

    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;

    // Scale ranges
    const double minRssi = -100;
    const double maxRssi = -30;
    const double minSnr = -20;
    const double maxSnr = 20;
    const double minChannelUtil = 0;
    const double maxChannelUtil = 100;

    // Grid line paint
    final Paint gridPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Text painter for labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = topInset + (chartHeight * (i / 4));

      canvas.drawLine(
        Offset(leftInset, y),
        Offset(leftInset + chartWidth, y),
        gridPaint,
      );

      // Left Y-axis label (RSSI/SNR scale)
      final rssiValue = maxRssi - (i * (maxRssi - minRssi) / 4);
      textPainter.text = TextSpan(
        text: '${rssiValue.toInt()}',
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 9,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftInset - textPainter.width - 6, y - 5),
      );

      // Right Y-axis label (Channel Util scale)
      final utilValue =
          maxChannelUtil - (i * (maxChannelUtil - minChannelUtil) / 4);
      textPainter.text = TextSpan(
        text: '${utilValue.toInt()}%',
        style: const TextStyle(
          color: channelUtilColor,
          fontSize: 9,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftInset + chartWidth + 6, y - 5));
    }

    if (data.length < 2) return;

    final stepX = chartWidth / (data.length - 1);

    // Draw X-axis time labels (only first and last)
    for (
      int i = 0;
      i < data.length;
      i += (data.length - 1).clamp(1, data.length - 1)
    ) {
      final x = leftInset + (i * stepX);
      final timeStr =
          '${data[i].time.minute.toString().padLeft(2, '0')}:${data[i].time.second.toString().padLeft(2, '0')}';
      textPainter.text = TextSpan(
        text: timeStr,
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 9,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      final xOffset = i == 0 ? x : x - textPainter.width;
      textPainter.paint(canvas, Offset(xOffset, size.height - bottomInset + 6));
    }

    // Draw RSSI line
    _drawLine(
      canvas,
      data.map((d) => d.rssi).toList(),
      minRssi,
      maxRssi,
      rssiColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      showFill: true,
    );

    // Draw SNR line (using same scale as RSSI for simplicity, normalized)
    _drawLine(
      canvas,
      data
          .map(
            (d) => _normalizeSnrToRssiScale(
              d.snr,
              minSnr,
              maxSnr,
              minRssi,
              maxRssi,
            ),
          )
          .toList(),
      minRssi,
      maxRssi,
      snrColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      showFill: false,
    );

    // Draw Channel Utilization line (using percentage scale, normalized)
    _drawLine(
      canvas,
      data
          .map(
            (d) => _normalizeUtilToRssiScale(
              d.channelUtil,
              minChannelUtil,
              maxChannelUtil,
              minRssi,
              maxRssi,
            ),
          )
          .toList(),
      minRssi,
      maxRssi,
      channelUtilColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      showFill: false,
      dashed: true,
    );

    // Draw current value dots for each line
    _drawDot(
      canvas,
      data.last.rssi,
      minRssi,
      maxRssi,
      rssiColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      data.length - 1,
    );
    _drawDot(
      canvas,
      _normalizeSnrToRssiScale(data.last.snr, minSnr, maxSnr, minRssi, maxRssi),
      minRssi,
      maxRssi,
      snrColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      data.length - 1,
    );
    _drawDot(
      canvas,
      _normalizeUtilToRssiScale(
        data.last.channelUtil,
        minChannelUtil,
        maxChannelUtil,
        minRssi,
        maxRssi,
      ),
      minRssi,
      maxRssi,
      channelUtilColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      data.length - 1,
    );
  }

  double _normalizeSnrToRssiScale(
    double snr,
    double minSnr,
    double maxSnr,
    double minRssi,
    double maxRssi,
  ) {
    // Map SNR (-20 to 20) to RSSI scale (-100 to -30)
    final normalized = (snr - minSnr) / (maxSnr - minSnr);
    return minRssi + normalized * (maxRssi - minRssi);
  }

  double _normalizeUtilToRssiScale(
    double util,
    double minUtil,
    double maxUtil,
    double minRssi,
    double maxRssi,
  ) {
    // Map Util (0 to 100) to RSSI scale (-100 to -30)
    final normalized = (util - minUtil) / (maxUtil - minUtil);
    return minRssi + normalized * (maxRssi - minRssi);
  }

  void _drawLine(
    Canvas canvas,
    List<double> values,
    double minValue,
    double maxValue,
    Color color,
    double leftInset,
    double topInset,
    double chartWidth,
    double chartHeight,
    double stepX, {
    bool showFill = false,
    bool dashed = false,
  }) {
    Path path = Path();
    Path fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = leftInset + (i * stepX);
      final value = values[i].clamp(minValue, maxValue);
      final y =
          topInset +
          chartHeight -
          ((value - minValue) / (maxValue - minValue)) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        if (showFill) {
          fillPath.moveTo(x, topInset + chartHeight);
          fillPath.lineTo(x, y);
        }
      } else {
        final prevX = leftInset + ((i - 1) * stepX);
        final prevValue = values[i - 1].clamp(minValue, maxValue);
        final prevY =
            topInset +
            chartHeight -
            ((prevValue - minValue) / (maxValue - minValue)) * chartHeight;

        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;

        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        if (showFill) {
          fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
        }
      }
    }

    if (showFill) {
      fillPath.lineTo(leftInset + chartWidth, topInset + chartHeight);
      fillPath.close();

      final Paint fillPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromLTWH(leftInset, topInset, chartWidth, chartHeight),
            );

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw glow effect
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(path, glowPaint);

    // Draw line
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (dashed) {
      _drawDashedPath(canvas, path, linePaint);
    } else {
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      bool draw = true;
      const dashLength = 6.0;
      const gapLength = 4.0;

      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          final extractedPath = metric.extractPath(distance, distance + length);
          canvas.drawPath(extractedPath, paint);
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  void _drawDot(
    Canvas canvas,
    double value,
    double minValue,
    double maxValue,
    Color color,
    double leftInset,
    double topInset,
    double chartWidth,
    double chartHeight,
    double stepX,
    int index,
  ) {
    final x = leftInset + (index * stepX);
    final clampedValue = value.clamp(minValue, maxValue);
    final y =
        topInset +
        chartHeight -
        ((clampedValue - minValue) / (maxValue - minValue)) * chartHeight;

    // Outer glow
    canvas.drawCircle(
      Offset(x, y),
      6,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // White outer ring
    canvas.drawCircle(
      Offset(x, y),
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Colored inner dot
    canvas.drawCircle(
      Offset(x, y),
      2.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DeviceDetailsTable extends StatelessWidget {
  final transport.DeviceInfo? device;
  final transport.DeviceConnectionState state;

  const _DeviceDetailsTable({required this.device, required this.state});

  String _getConnectionStateText(transport.DeviceConnectionState state) {
    switch (state) {
      case transport.DeviceConnectionState.connecting:
        return 'Connecting...';
      case transport.DeviceConnectionState.connected:
        return 'Connected';
      case transport.DeviceConnectionState.disconnecting:
        return 'Disconnecting...';
      case transport.DeviceConnectionState.error:
        return 'Connection Error';
      case transport.DeviceConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = state == transport.DeviceConnectionState.connected
        ? AppTheme.primaryGreen
        : AppTheme.textTertiary;

    final rssiColor = device?.rssi != null
        ? (device!.rssi! > -70
              ? AppTheme.primaryGreen
              : device!.rssi! > -85
              ? AppTheme.warningYellow
              : AppTheme.errorRed)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InfoTable(
        rows: [
          InfoTableRow(
            label: 'Device Name',
            value: device?.name ?? 'Unknown',
            icon: Icons.router,
            iconColor: AppTheme.primaryGreen,
          ),
          InfoTableRow(
            label: 'Status',
            value: _getConnectionStateText(state),
            icon: Icons.circle,
            iconColor: statusColor,
          ),
          InfoTableRow(
            label: 'Connection Type',
            value: device?.type == transport.TransportType.ble
                ? 'Bluetooth LE'
                : 'USB',
            icon: device?.type == transport.TransportType.ble
                ? Icons.bluetooth
                : Icons.usb,
            iconColor: AppTheme.graphBlue,
          ),
          if (device?.address != null)
            InfoTableRow(
              label: 'Address',
              value: device!.address!,
              icon: Icons.tag,
            ),
          if (device?.rssi != null)
            InfoTableRow(
              label: 'Signal Strength',
              value: '${device!.rssi} dBm',
              icon: Icons.signal_cellular_alt,
              iconColor: rssiColor,
            ),
        ],
      ),
    );
  }
}
