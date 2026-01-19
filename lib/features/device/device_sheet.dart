import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart';
import '../../utils/snackbar.dart';
import 'package:socialmesh/main.dart';

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
class _DeviceSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _DeviceSheetContent({required this.scrollController});

  @override
  ConsumerState<_DeviceSheetContent> createState() =>
      _DeviceSheetContentState();
}

class _DeviceSheetContentState extends ConsumerState<_DeviceSheetContent> {
  bool _disconnecting = false;

  @override
  Widget build(BuildContext context) {
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

    // Disable connection-required actions when disconnecting
    final actionsEnabled = !_disconnecting;

    // Use node's long name if available, otherwise fall back to device name
    final displayName =
        myNode?.longName ?? connectedDevice?.name ?? 'No Device';

    return Column(
      children: [
        // Header (DragPill is added by AppBottomSheet.showScrollable)
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
                      : context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.router,
                  color: isConnected
                      ? context.accentColor
                      : context.textTertiary,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoScrollText(
                      displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
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
                                : context.textTertiary,
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
                                : context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(color: context.border, height: 1),
        // Content
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Connection Details
              _buildSectionTitle(context, 'Connection Details'),
              const SizedBox(height: 12),
              _DeviceInfoCard(
                device: connectedDevice,
                connectionState: connectionState,
                batteryLevel: batteryLevel,
                nodeLongName: myNode?.longName,
              ),
              const SizedBox(height: 24),

              // Quick Actions
              _buildSectionTitle(context, 'Quick Actions'),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.tune_outlined,
                title: 'Device Config',
                subtitle: 'Configure device role and settings',
                enabled: actionsEnabled && isConnected,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/device-config');
                },
              ),
              _ActionTile(
                icon: Icons.wifi_tethering_outlined,
                title: 'Channels',
                subtitle: 'Manage communication channels',
                enabled: actionsEnabled && isConnected,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/channels');
                },
              ),
              _ActionTile(
                icon: Icons.qr_code_scanner,
                title: 'Scan Channel QR',
                subtitle: 'Import channel from QR code',
                enabled: actionsEnabled && isConnected,
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
              if (isConnected)
                _ActionTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Reset Node Database',
                  subtitle: 'Clear all learned nodes from device',
                  enabled: actionsEnabled,
                  onTap: () => _showResetNodeDbDialog(context),
                ),
              const SizedBox(height: 24),

              // Connection Actions
              if (isConnected) ...[
                _buildSectionTitle(context, 'Connection'),
                const SizedBox(height: 12),
                _buildDisconnectButton(context),
              ] else if (!isReconnecting) ...[
                _buildSectionTitle(context, 'Connection'),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.textTertiary,

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

  Widget _buildDisconnectButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _disconnecting ? null : () => _disconnect(context),
        icon: _disconnecting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorRed,
                ),
              )
            : const Icon(Icons.link_off, size: 20),
        label: Text(_disconnecting ? 'Disconnecting...' : 'Disconnect'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorRed,
          side: BorderSide(
            color: _disconnecting
                ? AppTheme.errorRed.withValues(alpha: 0.5)
                : AppTheme.errorRed,
          ),
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

  Future<void> _disconnect(BuildContext context) async {
    AppLogging.connection('🔌 DISCONNECT: User tapped disconnect button');

    // Capture providers BEFORE any async operations to avoid disposed ref access
    final userDisconnectedNotifier = ref.read(
      userDisconnectedProvider.notifier,
    );
    final autoReconnectNotifier = ref.read(autoReconnectStateProvider.notifier);
    final deviceConnectionNotifier = ref.read(
      deviceConnectionProvider.notifier,
    );
    final protocol = ref.read(protocolServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Disconnect'),
        content: const Text(
          'Are you sure you want to disconnect from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogging.connection('🔌 DISCONNECT: User cancelled dialog');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AppLogging.connection('🔌 DISCONNECT: User confirmed disconnect');
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      AppLogging.connection('🔌 DISCONNECT: Starting disconnect sequence...');

      // Immediately disable UI and show disconnecting state
      setState(() => _disconnecting = true);

      // CRITICAL: Set userDisconnected flag FIRST to prevent ALL auto-reconnect logic
      AppLogging.connection('🔌 DISCONNECT: Setting userDisconnected=true');
      userDisconnectedNotifier.setUserDisconnected(true);

      // Also set auto-reconnect state to idle for extra safety
      AppLogging.connection(
        '🔌 DISCONNECT: Setting autoReconnectState to idle (user disconnect)',
      );
      autoReconnectNotifier.setState(AutoReconnectState.idle);

      // Close sheet immediately to prevent further interaction
      // The disconnect will complete in the background
      AppLogging.connection('🔌 DISCONNECT: Closing sheet immediately');
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Now perform the actual disconnect in the background
      // Use DeviceConnectionNotifier for proper disconnect handling
      // This sets the proper disconnect reason and prevents auto-reconnect
      AppLogging.connection(
        '🔌 DISCONNECT: Calling DeviceConnectionNotifier.disconnect()',
      );
      await deviceConnectionNotifier.disconnect();

      // Also stop protocol service
      AppLogging.connection('🔌 DISCONNECT: Stopping protocol service');
      protocol.stop();

      AppLogging.connection('🔌 DISCONNECT: Disconnect sequence complete');

      // After a manual disconnect, navigate to the Scanner screen so the user
      // can immediately scan/connect to another device. This preserves the
      // previous behavior where manual disconnects showed the full scan
      // overlay, while automatic/out-of-range disconnects continue to show
      // only the inline banner.
      // Use the global navigatorKey so navigation succeeds even after the
      // sheet context has been popped.
      AppLogging.connection(
        '🔌 DISCONNECT: Navigating to Scanner (manual disconnect) - clearing back stack',
      );
      // Make Scanner the only route so the user cannot navigate back to prior
      // device-required screens after a manual disconnect.
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/scanner',
        (route) => false,
      );
    } else {
      AppLogging.connection(
        '🔌 DISCONNECT: Dialog dismissed or context not mounted',
      );
    }
  }

  Future<void> _showResetNodeDbDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Reset Node Database'),
        content: const Text(
          'This will clear all learned nodes from the device and app. '
          'The device will need to rediscover nodes on the mesh.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final protocol = ref.read(protocolServiceProvider);
        await protocol.nodeDbReset();

        // Clear local nodes from the app's state and storage
        ref.read(nodesProvider.notifier).clearNodes();

        if (context.mounted) {
          showSuccessSnackBar(context, 'Node database reset successfully');
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Failed to reset node database: $e');
        }
      }
    }
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final transport.DeviceInfo? device;
  final transport.DeviceConnectionState connectionState;
  final int? batteryLevel;
  final String? nodeLongName;

  const _DeviceInfoCard({
    required this.device,
    required this.connectionState,
    this.batteryLevel,
    this.nodeLongName,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        connectionState == transport.DeviceConnectionState.connected;

    final statusColor = isConnected
        ? context.accentColor
        : context.textTertiary;

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
        color: context.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: InfoTable(
        rows: [
          if (nodeLongName != null)
            InfoTableRow(
              label: 'Node Name',
              value: nodeLongName!,
              icon: Icons.person,
              iconColor: context.accentColor,
            ),
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
            iconColor: context.accentColor,
          ),
          if (device?.address != null)
            InfoTableRow(
              label: 'Address',
              value: device!.address!,
              icon: Icons.tag,
              iconColor: context.accentColor,
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
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onTap != null;
    final opacity = isEnabled ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: context.accentColor, size: 22),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
