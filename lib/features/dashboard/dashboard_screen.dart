import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Get the actual connection state value, defaulting to disconnected if loading
    final connectionState = connectionStateAsync.when(
      data: (state) => state,
      loading: () => transport.DeviceConnectionState.connecting,
      error: (error, stackTrace) => transport.DeviceConnectionState.error,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meshtastic'),
        actions: [
          // Connection status indicator
          IconButton(
            icon: Icon(
              connectionState == transport.DeviceConnectionState.connected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color:
                  connectionState == transport.DeviceConnectionState.connected
                  ? Colors.green
                  : Colors.red,
            ),
            onPressed: () {
              _showConnectionInfo(context, connectedDevice, connectionState);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _getConnectionStateText(connectionState),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Device info card
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(connectedDevice?.name ?? 'Unknown Device'),
                    subtitle: Text(
                      connectedDevice?.type == transport.TransportType.ble
                          ? 'Bluetooth'
                          : 'USB Serial',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _disconnect(context, ref),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // My node info
                if (myNodeNum != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('My Node'),
                      subtitle: Text('Node #$myNodeNum'),
                    ),
                  ),

                const SizedBox(height: 16),

                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.group,
                        label: 'Nodes',
                        value: '${nodes.length}',
                        onTap: () {
                          Navigator.of(context).pushNamed('/nodes');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.message,
                        label: 'Messages',
                        value: '${messages.length}',
                        onTap: () {
                          Navigator.of(context).pushNamed('/messages');
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                _ActionCard(
                  icon: Icons.message,
                  title: 'Messages',
                  subtitle: 'Send and receive messages',
                  onTap: () {
                    Navigator.of(context).pushNamed('/messages');
                  },
                ),

                _ActionCard(
                  icon: Icons.map,
                  title: 'Node Map',
                  subtitle: 'View nodes on a map',
                  onTap: () {
                    Navigator.of(context).pushNamed('/map');
                  },
                ),

                _ActionCard(
                  icon: Icons.group,
                  title: 'Nodes',
                  subtitle: 'View all discovered nodes',
                  onTap: () {
                    Navigator.of(context).pushNamed('/nodes');
                  },
                ),

                _ActionCard(
                  icon: Icons.wifi_tethering,
                  title: 'Channels',
                  subtitle: 'Manage communication channels',
                  onTap: () {
                    Navigator.of(context).pushNamed('/channels');
                  },
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

  void _showConnectionInfo(
    BuildContext context,
    transport.DeviceInfo? device,
    transport.DeviceConnectionState state,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device: ${device?.name ?? 'None'}'),
            Text('Status: ${_getConnectionStateText(state)}'),
            if (device?.rssi != null) Text('Signal: ${device!.rssi} dBm'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
  final String value;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label),
            ],
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
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
