import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import 'widgets/signal_strength_widget.dart';
import 'widgets/dashboard_widget_base.dart';

/// New customizable dashboard with widgets
class WidgetDashboardScreen extends ConsumerWidget {
  const WidgetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);
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

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Battery indicator
          if (batteryLevel != null && isConnected)
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
          // Device button - navigates to device page
          _DeviceButton(
            isConnected: isConnected,
            isReconnecting: isReconnecting,
          ),
          // Settings - navigates to settings page
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: !isConnected && !isReconnecting
          ? _buildDisconnectedState(context, autoReconnectState)
          : isReconnecting
          ? _buildReconnectingState(context, autoReconnectState)
          : _buildDashboard(context, ref, nodes, messages),
    );
  }

  Widget _buildDisconnectedState(
    BuildContext context,
    AutoReconnectState autoReconnectState,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              autoReconnectState == AutoReconnectState.failed
                  ? Icons.wifi_off
                  : Icons.bluetooth_disabled,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              autoReconnectState == AutoReconnectState.failed
                  ? 'Connection Failed'
                  : 'No Device Connected',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              autoReconnectState == AutoReconnectState.failed
                  ? 'Could not find saved device'
                  : 'Connect to a Meshtastic device to get started',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/scanner'),
              icon: const Icon(Icons.bluetooth_searching, size: 20),
              label: const Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectingState(
    BuildContext context,
    AutoReconnectState autoReconnectState,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 24),
          Text(
            autoReconnectState == AutoReconnectState.scanning
                ? 'Scanning for device...'
                : 'Connecting...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while we reconnect',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    Map<int, dynamic> nodes,
    List<dynamic> messages,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats Row
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                icon: Icons.group_outlined,
                label: 'Nodes',
                value: '${nodes.length}',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCardWidget(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                value: '${messages.length}',
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Signal Strength Section
        _buildSectionHeader('Signal Strength'),
        const SizedBox(height: 12),
        const SignalStrengthWidget(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        fontFamily: 'Inter',
        letterSpacing: 0.5,
      ),
    );
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

  Color _getBatteryColor(int level) {
    if (level > 100) return AppTheme.primaryGreen;
    if (level >= 50) return AppTheme.primaryGreen;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

/// Device button that shows connection status and navigates to device page
class _DeviceButton extends StatelessWidget {
  final bool isConnected;
  final bool isReconnecting;

  const _DeviceButton({
    required this.isConnected,
    required this.isReconnecting,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.router,
            color: isConnected
                ? AppTheme.primaryGreen
                : isReconnecting
                ? AppTheme.warningYellow
                : AppTheme.textTertiary,
          ),
          // Status dot
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isConnected
                    ? AppTheme.primaryGreen
                    : isReconnecting
                    ? AppTheme.warningYellow
                    : AppTheme.errorRed,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.darkBackground, width: 2),
              ),
            ),
          ),
        ],
      ),
      onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
      tooltip: 'Device',
    );
  }
}
