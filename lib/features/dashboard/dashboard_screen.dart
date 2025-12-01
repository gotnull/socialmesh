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
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);

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
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
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

                // Device Actions Section
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Device Actions',
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

                _ActionCard(
                  icon: Icons.bluetooth_searching,
                  title: 'Scan for Devices',
                  subtitle: 'Find and connect to other devices',
                  onTap: () => Navigator.of(context).pushNamed('/scanner'),
                ),
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
