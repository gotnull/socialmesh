import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';

class NodesScreen extends ConsumerStatefulWidget {
  const NodesScreen({super.key});

  @override
  ConsumerState<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends ConsumerState<NodesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    var nodesList = nodes.values.toList()
      ..sort((a, b) {
        // Favorites first
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        // My node second
        if (a.nodeNum == myNodeNum) return -1;
        if (b.nodeNum == myNodeNum) return 1;
        // Then by last heard (most recent first)
        if (a.lastHeard == null) return 1;
        if (b.lastHeard == null) return -1;
        return b.lastHeard!.compareTo(a.lastHeard!);
      });

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      nodesList = nodesList.where((node) {
        final query = _searchQuery.toLowerCase();
        return node.displayName.toLowerCase().contains(query) ||
            node.userId?.toLowerCase().contains(query) == true ||
            node.nodeNum.toString().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          'Nodes (${nodes.length})',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
                decoration: const InputDecoration(
                  hintText: 'Find a node',
                  hintStyle: TextStyle(
                    color: AppTheme.textTertiary,
                    fontFamily: 'Inter',
                  ),
                  prefixIcon: Icon(Icons.search, color: AppTheme.textTertiary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
          // Node list
          Expanded(
            child: nodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.group,
                            size: 40,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No nodes discovered yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: nodesList.length,
                    itemBuilder: (context, index) {
                      final node = nodesList[index];
                      final isMyNode = node.nodeNum == myNodeNum;

                      return _NodeCard(
                        node: node,
                        isMyNode: isMyNode,
                        onTap: () => _showNodeDetails(context, node, isMyNode),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showNodeDetails(BuildContext context, MeshNode node, bool isMyNode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      builder: (context) => _NodeDetailsSheet(node: node, isMyNode: isMyNode),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final VoidCallback onTap;

  const _NodeCard({
    required this.node,
    required this.isMyNode,
    required this.onTap,
  });

  Color _getAvatarColor() {
    if (node.avatarColor != null) {
      return Color(node.avatarColor!);
    }
    // Generate color from node ID
    final colors = [
      const Color(0xFF5B4FCE), // Purple like 29a9
      const Color(0xFFD946A6), // Pink like 2d94
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF10B981), // Green
    ];
    return colors[node.nodeNum % colors.length];
  }

  String _getShortName() {
    return node.shortName ??
        node.longName?.substring(0, 4) ??
        node.nodeNum.toRadixString(16);
  }

  int _calculateSignalBars(int? rssi) {
    if (rssi == null) return 0;
    if (rssi >= -70) return 4;
    if (rssi >= -80) return 3;
    if (rssi >= -90) return 2;
    if (rssi >= -100) return 1;
    return 0;
  }

  String _formatDistance(double? distance) {
    if (distance == null) return '';
    if (distance < 1000) {
      return '${distance.toInt()} m away';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  String _formatLastHeard(DateTime time) {
    final dateFormat = DateFormat('dd/MM/yyyy, h:mma');
    return dateFormat.format(time);
  }

  @override
  Widget build(BuildContext context) {
    final signalBars = _calculateSignalBars(node.rssi);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _getAvatarColor(),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _getShortName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // PWD/Battery indicator
                    if (node.role != null || node.batteryLevel != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (node.role == 'CLIENT')
                            const Icon(
                              Icons.bluetooth,
                              size: 14,
                              color: AppTheme.primaryGreen,
                            ),
                          if (node.batteryLevel != null) ...[
                            if (node.role != null) const SizedBox(width: 4),
                            Icon(
                              Icons.battery_std,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            Text(
                              '${node.batteryLevel}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Lock icon
                          const Icon(
                            Icons.lock,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          // Name
                          Expanded(
                            child: Text(
                              node.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Status
                      Row(
                        children: [
                          Icon(
                            node.isOnline ? Icons.wifi : Icons.wifi_off,
                            size: 14,
                            color: node.isOnline
                                ? AppTheme.primaryGreen
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            node.isOnline ? 'Connected' : 'Offline',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Last heard
                      if (node.lastHeard != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 14,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatLastHeard(node.lastHeard!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Role
                      if (node.role != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.smartphone,
                              size: 14,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Role: ${node.role}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      // Distance & heading
                      if (node.distance != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me,
                              size: 14,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDistance(node.distance),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Logs indicators
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.article,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Logs:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.message,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.place,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                        ],
                      ),
                      // Signal bars
                      if (node.rssi != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.signal_cellular_alt,
                              size: 14,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Signal Good',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Signal strength bars
                            Row(
                              children: List.generate(4, (i) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  width: 4,
                                  height: 12 + (i * 3.0),
                                  decoration: BoxDecoration(
                                    color: i < signalBars
                                        ? AppTheme.primaryGreen
                                        : AppTheme.textTertiary.withValues(
                                            alpha: 0.3,
                                          ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Favorite star & chevron
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (node.isFavorite)
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 24)
                    else
                      const SizedBox(height: 24),
                    const SizedBox(height: 32),
                    const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textTertiary,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeDetailsSheet extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;

  const _NodeDetailsSheet({required this.node, required this.isMyNode});

  Color _getAvatarColor() {
    if (node.avatarColor != null) {
      return Color(node.avatarColor!);
    }
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];
    return colors[node.nodeNum % colors.length];
  }

  String _getShortName() {
    return node.shortName ??
        node.longName?.substring(0, 4) ??
        node.nodeNum.toRadixString(16);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _getAvatarColor(),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getShortName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Node #${node.nodeNum}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            height: 1,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
          _DetailRow(
            icon: Icons.badge,
            label: 'User ID',
            value: node.userId ?? 'Unknown',
          ),
          if (node.role != null)
            _DetailRow(
              icon: Icons.smartphone,
              label: 'Role',
              value: node.role!,
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
          if (node.rssi != null)
            _DetailRow(
              icon: Icons.signal_cellular_alt,
              label: 'RSSI',
              value: '${node.rssi} dBm',
            ),
          if (node.snr != null)
            _DetailRow(
              icon: Icons.signal_cellular_alt,
              label: 'SNR',
              value: '${node.snr} dB',
            ),
          if (node.distance != null)
            _DetailRow(
              icon: Icons.near_me,
              label: 'Distance',
              value: node.distance! < 1000
                  ? '${node.distance!.toInt()} m'
                  : '${(node.distance! / 1000).toStringAsFixed(1)} km',
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
          const SizedBox(height: 24),
          if (!isMyNode)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/messages',
                    arguments: node.nodeNum,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.message),
                label: const Text(
                  'Send Message',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: AppTheme.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'This is your device',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
