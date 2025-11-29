import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
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
                  const SizedBox(width: 2),
                  Text(
                    _getBatteryText(batteryLevel),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getBatteryColor(batteryLevel),
                      fontFamily: 'Inter',
                    ),
                  ),
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

  String _getBatteryText(int level) {
    if (level > 100) return 'Charging';
    return '$level%';
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
  final List<_SignalData> _signalHistory = [];
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
    final now = DateTime.now();
    final rssiValue = rssiAsync.valueOrNull?.toDouble() ?? -90.0;
    _signalHistory.add(_SignalData(time: now, rssi: rssiValue));
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
                      Text(
                        'Bluetooth LE Signal Strength',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                          fontFamily: 'Inter',
                        ),
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
          // Chart
          SizedBox(
            height: 160,
            child: hasData
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                    child: CustomPaint(
                      painter: _SignalChartPainter(_signalHistory),
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

class _SignalData {
  final DateTime time;
  final double rssi;

  _SignalData({required this.time, required this.rssi});
}

class _SignalChartPainter extends CustomPainter {
  final List<_SignalData> data;

  _SignalChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftInset = 42.0;
    const bottomInset = 20.0;
    const topInset = 4.0;
    const rightInset = 4.0;

    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;

    const double minRssi = -100;
    const double maxRssi = -30;

    // Grid line paint
    final Paint gridPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Text painter for labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines and Y-axis labels
    for (int i = 0; i <= 4; i++) {
      final y = topInset + (chartHeight * (i / 4));

      // Draw grid line
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(leftInset + chartWidth, y),
        gridPaint,
      );

      // Draw Y-axis label
      final rssiValue = maxRssi - (i * (maxRssi - minRssi) / 4);
      textPainter.text = TextSpan(
        text: '${rssiValue.toInt()}',
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 10,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftInset - textPainter.width - 8, y - 6),
      );
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

    // Create gradient for line based on signal strength
    Path path = Path();
    Path fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = leftInset + (i * stepX);
      final rssi = data[i].rssi.clamp(minRssi, maxRssi);
      final y =
          topInset +
          chartHeight -
          ((rssi - minRssi) / (maxRssi - minRssi)) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topInset + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve using cubic bezier
        final prevX = leftInset + ((i - 1) * stepX);
        final prevRssi = data[i - 1].rssi.clamp(minRssi, maxRssi);
        final prevY =
            topInset +
            chartHeight -
            ((prevRssi - minRssi) / (maxRssi - minRssi)) * chartHeight;

        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;

        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(leftInset + chartWidth, topInset + chartHeight);
    fillPath.close();

    // Get current rssi for color
    final currentRssi = data.last.rssi;
    Color lineColor;
    if (currentRssi >= -60) {
      lineColor = AppTheme.primaryGreen;
    } else if (currentRssi >= -75) {
      lineColor = AppTheme.warningYellow;
    } else {
      lineColor = AppTheme.errorRed;
    }

    // Draw gradient fill
    final Paint fillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.25),
              lineColor.withValues(alpha: 0.05),
              lineColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromLTWH(leftInset, topInset, chartWidth, chartHeight),
          );

    canvas.drawPath(fillPath, fillPaint);

    // Draw line with glow effect
    final Paint glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, glowPaint);

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw current value dot
    if (data.isNotEmpty) {
      final lastX = leftInset + ((data.length - 1) * stepX);
      final lastRssi = data.last.rssi.clamp(minRssi, maxRssi);
      final lastY =
          topInset +
          chartHeight -
          ((lastRssi - minRssi) / (maxRssi - minRssi)) * chartHeight;

      // Outer glow
      canvas.drawCircle(
        Offset(lastX, lastY),
        8,
        Paint()
          ..color = lineColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // White outer ring
      canvas.drawCircle(
        Offset(lastX, lastY),
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      // Colored inner dot
      canvas.drawCircle(
        Offset(lastX, lastY),
        3.5,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill,
      );
    }
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
    final details = <(String, String, IconData?, Color?)>[
      (
        'Device Name',
        device?.name ?? 'Unknown',
        Icons.router,
        AppTheme.primaryGreen,
      ),
      (
        'Status',
        _getConnectionStateText(state),
        Icons.circle,
        state == transport.DeviceConnectionState.connected
            ? AppTheme.primaryGreen
            : AppTheme.textTertiary,
      ),
      (
        'Connection Type',
        device?.type == transport.TransportType.ble ? 'Bluetooth LE' : 'USB',
        device?.type == transport.TransportType.ble
            ? Icons.bluetooth
            : Icons.usb,
        AppTheme.graphBlue,
      ),
      if (device?.address != null)
        ('Address', device!.address!, Icons.tag, null),
      if (device?.rssi != null)
        (
          'Signal Strength',
          '${device!.rssi} dBm',
          Icons.signal_cellular_alt,
          device!.rssi! > -70
              ? AppTheme.primaryGreen
              : device!.rssi! > -85
              ? AppTheme.warningYellow
              : AppTheme.errorRed,
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: details.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isOdd = index % 2 == 1;

            return Container(
              decoration: BoxDecoration(
                color: isOdd
                    ? const Color(0xFF29303D)
                    : AppTheme.darkBackground,
                border: Border(
                  bottom: index < details.length - 1
                      ? const BorderSide(color: AppTheme.darkBorder, width: 1)
                      : BorderSide.none,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: AppTheme.darkBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (item.$3 != null) ...[
                              Icon(
                                item.$3,
                                size: 16,
                                color: item.$4 ?? AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textTertiary,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
