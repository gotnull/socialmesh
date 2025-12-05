import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/info_table.dart';
import '../../providers/app_providers.dart';

/// Shows the device sheet as a modal bottom sheet
void showDeviceSheet(BuildContext context) {
  AppBottomSheet.showScrollable(
    context: context,
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (scrollController) =>
        _DeviceSheetContent(scrollController: scrollController),
  );
}

/// Device information and controls sheet content
class _DeviceSheetContent extends ConsumerWidget {
  final ScrollController scrollController;

  const _DeviceSheetContent({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final batteryLevel = myNode?.batteryLevel;

    final connectionState = connectionStateAsync.when(
      data: (state) => state,
      loading: () => transport.DeviceConnectionState.connecting,
      error: (_, _) => transport.DeviceConnectionState.error,
    );

    final isConnected =
        connectionState == transport.DeviceConnectionState.connected;
    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    return Column(
      children: [
        const DragPill(),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnected
                      ? context.accentColor.withValues(alpha: 0.15)
                      : AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.router,
                  color: isConnected
                      ? context.accentColor
                      : AppTheme.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectedDevice?.name ?? 'No Device',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? context.accentColor
                                : isReconnecting
                                ? AppTheme.warningYellow
                                : AppTheme.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          _getStatusText(connectionState, autoReconnectState),
                          style: TextStyle(
                            fontSize: 14,
                            color: isConnected
                                ? context.accentColor
                                : isReconnecting
                                ? AppTheme.warningYellow
                                : AppTheme.textTertiary,
                            
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(color: AppTheme.darkBorder, height: 1),
        // Content
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Connection Details
              _buildSectionTitle('Connection Details'),
              const SizedBox(height: 12),
              _DeviceInfoCard(
                device: connectedDevice,
                connectionState: connectionState,
                batteryLevel: batteryLevel,
              ),
              const SizedBox(height: 24),

              // Quick Actions
              _buildSectionTitle('Quick Actions'),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.tune_outlined,
                title: 'Device Config',
                subtitle: 'Configure device role and settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/device-config');
                },
              ),
              _ActionTile(
                icon: Icons.wifi_tethering_outlined,
                title: 'Channels',
                subtitle: 'Manage communication channels',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/channels');
                },
              ),
              _ActionTile(
                icon: Icons.qr_code_scanner,
                title: 'Scan Channel QR',
                subtitle: 'Import channel from QR code',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/channel-qr-scanner');
                },
              ),
              _ActionTile(
                icon: Icons.settings_outlined,
                title: 'App Settings',
                subtitle: 'Notifications, theme, preferences',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/settings');
                },
              ),
              const SizedBox(height: 24),

              // Connection Actions
              if (isConnected) ...[
                _buildSectionTitle('Connection'),
                const SizedBox(height: 12),
                _buildDisconnectButton(context, ref),
              ] else if (!isReconnecting) ...[
                _buildSectionTitle('Connection'),
                const SizedBox(height: 12),
                _buildScanButton(context),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textTertiary,
        
        letterSpacing: 1,
      ),
    );
  }

  String _getStatusText(
    transport.DeviceConnectionState state,
    AutoReconnectState autoReconnectState,
  ) {
    if (autoReconnectState == AutoReconnectState.scanning) {
      return 'Reconnecting...';
    }
    if (autoReconnectState == AutoReconnectState.connecting) {
      return 'Connecting...';
    }
    switch (state) {
      case transport.DeviceConnectionState.connected:
        return 'Connected';
      case transport.DeviceConnectionState.connecting:
        return 'Connecting...';
      case transport.DeviceConnectionState.disconnecting:
        return 'Disconnecting...';
      case transport.DeviceConnectionState.error:
        return 'Error';
      case transport.DeviceConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  Widget _buildDisconnectButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _disconnect(context, ref),
        icon: const Icon(Icons.link_off, size: 20),
        label: const Text('Disconnect'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorRed,
          side: const BorderSide(color: AppTheme.errorRed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          Navigator.of(context).pushNamed('/scanner');
        },
        icon: Icon(Icons.bluetooth_searching, size: 20),
        label: Text('Scan for Devices'),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Disconnect'),
        content: const Text(
          'Are you sure you want to disconnect from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final protocol = ref.read(protocolServiceProvider);
      protocol.stop();

      final transport = ref.read(transportProvider);
      await transport.disconnect();

      ref.read(connectedDeviceProvider.notifier).state = null;

      if (context.mounted) {
        Navigator.pop(context); // Close the sheet
      }
    }
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final transport.DeviceInfo? device;
  final transport.DeviceConnectionState connectionState;
  final int? batteryLevel;

  const _DeviceInfoCard({
    required this.device,
    required this.connectionState,
    this.batteryLevel,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        connectionState == transport.DeviceConnectionState.connected;

    final statusColor = isConnected
        ? context.accentColor
        : AppTheme.textTertiary;

    final rssiColor = device?.rssi != null
        ? (device!.rssi! > -70
              ? context.accentColor
              : device!.rssi! > -85
              ? AppTheme.warningYellow
              : AppTheme.errorRed)
        : null;

    final batteryColor = batteryLevel != null
        ? (batteryLevel! > 100
              ? AppTheme
                    .primaryGreen // Charging
              : batteryLevel! >= 50
              ? context.accentColor
              : batteryLevel! >= 20
              ? AppTheme.warningYellow
              : AppTheme.errorRed)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: InfoTable(
        rows: [
          InfoTableRow(
            label: 'Device Name',
            value: device?.name ?? 'Unknown',
            icon: Icons.router,
            iconColor: context.accentColor,
          ),
          InfoTableRow(
            label: 'Status',
            value: _getConnectionStateText(connectionState),
            icon: Icons.circle,
            iconColor: statusColor,
          ),
          InfoTableRow(
            label: 'Connection Type',
            value: device?.type == transport.TransportType.ble
                ? 'Bluetooth LE'
                : device?.type == transport.TransportType.usb
                ? 'USB'
                : 'Unknown',
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
          if (device?.rssi != null && isConnected)
            InfoTableRow(
              label: 'Signal Strength',
              value: '${device!.rssi} dBm',
              icon: Icons.signal_cellular_alt,
              iconColor: rssiColor,
            ),
          if (batteryLevel != null && isConnected)
            InfoTableRow(
              label: 'Battery',
              value: batteryLevel! > 100 ? 'Charging' : '$batteryLevel%',
              icon: _getBatteryIcon(batteryLevel!),
              iconColor: batteryColor,
            ),
        ],
      ),
    );
  }

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

  IconData _getBatteryIcon(int level) {
    if (level > 100) return Icons.battery_charging_full;
    if (level >= 95) return Icons.battery_full;
    if (level >= 80) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    if (level >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
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
        color: AppTheme.darkBackground,
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: context.accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
