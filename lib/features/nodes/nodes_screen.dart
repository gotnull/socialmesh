import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';

class NodesScreen extends ConsumerWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    final nodesList = nodes.values.toList()
      ..sort((a, b) {
        // My node first
        if (a.nodeNum == myNodeNum) return -1;
        if (b.nodeNum == myNodeNum) return 1;
        // Then by last heard (most recent first)
        if (a.lastHeard == null) return 1;
        if (b.lastHeard == null) return -1;
        return b.lastHeard!.compareTo(a.lastHeard!);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Nodes'),
      ),
      body: nodes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  const Text('No nodes discovered yet'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: nodesList.length,
              itemBuilder: (context, index) {
                final node = nodesList[index];
                final isMyNode = node.nodeNum == myNodeNum;

                return _NodeTile(
                  node: node,
                  isMyNode: isMyNode,
                  onTap: () => _showNodeDetails(context, node, isMyNode),
                );
              },
            ),
    );
  }

  void _showNodeDetails(BuildContext context, MeshNode node, bool isMyNode) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _NodeDetailsSheet(
        node: node,
        isMyNode: isMyNode,
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final VoidCallback onTap;

  const _NodeTile({
    required this.node,
    required this.isMyNode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isMyNode
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          isMyNode ? Icons.person : Icons.person_outline,
          color: isMyNode
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(node.displayName)),
          if (isMyNode)
            Chip(
              label: const Text('Me'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Node #${node.nodeNum}'),
          if (node.lastHeard != null)
            Text(
              'Last heard: ${_formatLastHeard(node.lastHeard!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.batteryLevel != null) ...[
            Icon(
              _getBatteryIcon(node.batteryLevel!),
              size: 20,
            ),
            const SizedBox(width: 4),
            Text('${node.batteryLevel}%'),
            const SizedBox(width: 8),
          ],
          if (node.snr != null)
            Chip(
              label: Text('${node.snr} dB'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level > 90) return Icons.battery_full;
    if (level > 60) return Icons.battery_5_bar;
    if (level > 40) return Icons.battery_4_bar;
    if (level > 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  String _formatLastHeard(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _NodeDetailsSheet extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;

  const _NodeDetailsSheet({
    required this.node,
    required this.isMyNode,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isMyNode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  isMyNode ? Icons.person : Icons.person_outline,
                  size: 32,
                  color: isMyNode
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Node #${node.nodeNum}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _DetailRow(
            icon: Icons.badge,
            label: 'User ID',
            value: node.userId ?? 'Unknown',
          ),
          if (node.hardwareModel != null)
            _DetailRow(
              icon: Icons.memory,
              label: 'Hardware',
              value: node.hardwareModel!,
            ),
          if (node.firmwareVersion != null)
            _DetailRow(
              icon: Icons.system_update,
              label: 'Firmware',
              value: node.firmwareVersion!,
            ),
          if (node.batteryLevel != null)
            _DetailRow(
              icon: Icons.battery_charging_full,
              label: 'Battery',
              value: '${node.batteryLevel}%',
            ),
          if (node.snr != null)
            _DetailRow(
              icon: Icons.signal_cellular_alt,
              label: 'SNR',
              value: '${node.snr} dB',
            ),
          if (node.hasPosition)
            _DetailRow(
              icon: Icons.location_on,
              label: 'Position',
              value:
                  '${node.latitude!.toStringAsFixed(4)}, ${node.longitude!.toStringAsFixed(4)}',
            ),
          if (node.altitude != null)
            _DetailRow(
              icon: Icons.height,
              label: 'Altitude',
              value: '${node.altitude}m',
            ),
          if (node.lastHeard != null)
            _DetailRow(
              icon: Icons.access_time,
              label: 'Last Heard',
              value: dateFormat.format(node.lastHeard!),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/messages',
                      arguments: node.nodeNum,
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Send Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
