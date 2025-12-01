import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../messaging/messaging_screen.dart';

// Battery helper functions
// Meshtastic uses 101 for charging, 100 for plugged in fully charged
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
  if (level > 100) return AppTheme.primaryGreen; // Charging
  if (level >= 50) return AppTheme.primaryGreen;
  if (level >= 20) return AppTheme.warningYellow;
  return AppTheme.errorRed;
}

class NodesScreen extends ConsumerStatefulWidget {
  const NodesScreen({super.key});

  @override
  ConsumerState<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends ConsumerState<NodesScreen> {
  String _searchQuery = '';

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    var nodesList = nodes.values.toList()
      ..sort((a, b) {
        // My node always first
        if (a.nodeNum == myNodeNum) return -1;
        if (b.nodeNum == myNodeNum) return 1;
        // Favorites second
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
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

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
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
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.textTertiary,
                    ),
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
                          onTap: () =>
                              _showNodeDetails(context, node, isMyNode),
                        );
                      },
                    ),
            ),
          ],
        ),
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
        color: isMyNode
            ? AppTheme.primaryGreen.withValues(alpha: 0.08)
            : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyNode
              ? AppTheme.primaryGreen.withValues(alpha: 0.5)
              : AppTheme.darkBorder,
          width: isMyNode ? 1.5 : 1,
        ),
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
                    Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isMyNode
                                ? AppTheme.primaryGreen
                                : _getAvatarColor(),
                            shape: BoxShape.circle,
                            border: isMyNode
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  )
                                : null,
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
                        // "You" indicator on avatar
                        if (isMyNode)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.darkCard,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 12,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                      ],
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
                              _getBatteryIcon(node.batteryLevel!),
                              size: 14,
                              color: _getBatteryColor(node.batteryLevel!),
                            ),
                            // Only show percentage text if not charging
                            if (node.batteryLevel! <= 100)
                              Text(
                                '${node.batteryLevel}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getBatteryColor(node.batteryLevel!),
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
                          Flexible(
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
                          // "You" badge
                          if (isMyNode) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Status - show "This Device" for your own node
                      if (isMyNode)
                        Row(
                          children: [
                            Icon(
                              Icons.smartphone,
                              size: 14,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'This Device',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        )
                      else
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
                      // Role and GPS status
                      Row(
                        children: [
                          if (node.role != null) ...[
                            const Icon(
                              Icons.smartphone,
                              size: 14,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              node.role!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Icon(
                            Icons.gps_fixed,
                            size: 14,
                            color: node.hasPosition
                                ? AppTheme.primaryGreen
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            node.hasPosition ? 'GPS' : 'No GPS',
                            style: TextStyle(
                              fontSize: 12,
                              color: node.hasPosition
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textTertiary,
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

class _NodeDetailsSheet extends ConsumerWidget {
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

  void _showNodeQrCode(BuildContext context) {
    // Create a shareable node info JSON
    final nodeInfo = {
      'nodeNum': node.nodeNum,
      'longName': node.longName ?? node.displayName,
      'shortName': node.shortName ?? _getShortName(),
      if (node.userId != null) 'userId': node.userId,
      if (node.hasPosition) 'lat': node.latitude,
      if (node.hasPosition) 'lon': node.longitude,
    };
    final nodeJson = jsonEncode(nodeInfo);
    final nodeUrl = 'meshtastic://node/${base64Encode(utf8.encode(nodeJson))}';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        minimum: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code,
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
                          node.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan to add this node',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: nodeUrl,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1F2633),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1F2633),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Node ID info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.tag,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Node ID: ${node.nodeNum.toRadixString(16).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Copy button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            '${node.displayName}\nNode: !${node.nodeNum.toRadixString(16)}',
                      ),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Node info copied'),
                        backgroundColor: AppTheme.darkCard,
                        behavior: SnackBarBehavior.floating,
                      ),
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
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text(
                    'Copy Node Info',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendDirectMessage(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: node.nodeNum,
          title: node.displayName,
        ),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    Navigator.pop(context);

    try {
      if (node.isFavorite) {
        await protocol.removeFavoriteNode(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: false));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${node.displayName} removed from favorites'),
              backgroundColor: AppTheme.darkCard,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await protocol.setFavoriteNode(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: true));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${node.displayName} added to favorites'),
              backgroundColor: AppTheme.darkCard,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRebootConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: AppTheme.warningYellow, size: 24),
            SizedBox(width: 12),
            Text(
              'Reboot Device',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        content: const Text(
          'This will reboot your Meshtastic device. The app will automatically reconnect once the device restarts.',
          style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);

              final protocol = ref.read(protocolServiceProvider);

              try {
                await protocol.reboot();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device is rebooting...'),
                      backgroundColor: AppTheme.darkCard,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reboot: $e'),
                      backgroundColor: AppTheme.errorRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reboot',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showShutdownConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new, color: AppTheme.errorRed, size: 24),
            SizedBox(width: 12),
            Text(
              'Shutdown Device',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        content: const Text(
          'This will turn off your Meshtastic device. You will need to physically power it back on to reconnect.',
          style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);

              final protocol = ref.read(protocolServiceProvider);

              try {
                await protocol.shutdown();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device is shutting down...'),
                      backgroundColor: AppTheme.darkCard,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to shutdown: $e'),
                      backgroundColor: AppTheme.errorRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Shutdown',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _removeNode(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Node',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        content: Text(
          'Remove ${node.displayName} from the node database? This will remove the node from your local device.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);

              final protocol = ref.read(protocolServiceProvider);

              try {
                await protocol.removeNode(node.nodeNum);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${node.displayName} removed'),
                      backgroundColor: AppTheme.darkCard,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove node: $e'),
                      backgroundColor: AppTheme.errorRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _setFixedPosition(BuildContext context, WidgetRef ref) async {
    if (!node.hasPosition) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Node has no position data'),
          backgroundColor: AppTheme.darkCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context);

    final protocol = ref.read(protocolServiceProvider);

    try {
      // Sets the connected device's fixed position to this node's location
      await protocol.setFixedPosition(
        latitude: node.latitude!,
        longitude: node.longitude!,
        altitude: node.altitude ?? 0,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fixed position set to ${node.displayName}\'s location',
            ),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set fixed position: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _exchangePositions(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);

    final protocol = ref.read(protocolServiceProvider);

    try {
      // Request position from the target node
      await protocol.requestPosition(node.nodeNum);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Position requested from ${node.displayName}'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request position: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        minimum: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.swap_horiz,
                color: AppTheme.primaryGreen,
              ),
              title: const Text(
                'Exchange Positions',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
              ),
              subtitle: const Text(
                'Request GPS position from this node',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _exchangePositions(context, ref);
              },
            ),
            ListTile(
              leading: Icon(
                node.isFavorite ? Icons.star : Icons.star_border,
                color: node.isFavorite
                    ? AppTheme.warningYellow
                    : AppTheme.textSecondary,
              ),
              title: Text(
                node.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleFavorite(context, ref);
              },
            ),
            if (node.hasPosition)
              ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: AppTheme.textSecondary,
                ),
                title: const Text(
                  'Set as Fixed Position',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setFixedPosition(context, ref);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorRed,
              ),
              title: const Text(
                'Remove Node',
                style: TextStyle(color: AppTheme.errorRed, fontFamily: 'Inter'),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _removeNode(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  color: isMyNode ? AppTheme.primaryGreen : _getAvatarColor(),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            node.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        if (isMyNode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '!${node.nodeNum.toRadixString(16)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // QR code button
              IconButton(
                onPressed: () => _showNodeQrCode(context),
                icon: const Icon(Icons.qr_code, color: AppTheme.textSecondary),
                tooltip: 'Show QR Code',
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            height: 1,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),

          // Scrollable details
          Flexible(
            child: SingleChildScrollView(
              child: InfoTable(
                rows: [
                  InfoTableRow(
                    icon: Icons.badge,
                    label: 'User ID',
                    value: node.userId ?? 'Unknown',
                  ),
                  if (node.role != null)
                    InfoTableRow(
                      icon: Icons.smartphone,
                      label: 'Role',
                      value: node.role!,
                    ),
                  if (node.hardwareModel != null)
                    InfoTableRow(
                      icon: Icons.memory,
                      label: 'Hardware',
                      value: node.hardwareModel!,
                    ),
                  if (node.firmwareVersion != null)
                    InfoTableRow(
                      icon: Icons.system_update,
                      label: 'Firmware',
                      value: node.firmwareVersion!,
                    ),
                  if (node.batteryLevel != null)
                    InfoTableRow(
                      icon: _getBatteryIcon(node.batteryLevel!),
                      iconColor: _getBatteryColor(node.batteryLevel!),
                      label: 'Battery',
                      value: node.batteryLevel! > 100
                          ? 'Charging'
                          : '${node.batteryLevel}%',
                    ),
                  if (node.rssi != null)
                    InfoTableRow(
                      icon: Icons.signal_cellular_alt,
                      label: 'RSSI',
                      value: '${node.rssi} dBm',
                    ),
                  if (node.snr != null)
                    InfoTableRow(
                      icon: Icons.wifi,
                      label: 'SNR',
                      value: '${node.snr} dB',
                    ),
                  if (node.distance != null)
                    InfoTableRow(
                      icon: Icons.near_me,
                      label: 'Distance',
                      value: node.distance! < 1000
                          ? '${node.distance!.toInt()} m'
                          : '${(node.distance! / 1000).toStringAsFixed(1)} km',
                    ),
                  if (node.hasPosition)
                    InfoTableRow(
                      icon: Icons.location_on,
                      label: 'Position',
                      value:
                          '${node.latitude!.toStringAsFixed(5)}, ${node.longitude!.toStringAsFixed(5)}',
                    ),
                  if (node.altitude != null)
                    InfoTableRow(
                      icon: Icons.height,
                      label: 'Altitude',
                      value: '${node.altitude}m',
                    ),
                  if (node.lastHeard != null)
                    InfoTableRow(
                      icon: Icons.access_time,
                      label: 'Last Heard',
                      value: dateFormat.format(node.lastHeard!),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          if (!isMyNode)
            Column(
              children: [
                // Primary actions row
                Row(
                  children: [
                    // Favorite button
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.darkBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _toggleFavorite(context, ref),
                        icon: Icon(
                          node.isFavorite ? Icons.star : Icons.star_border,
                          color: node.isFavorite
                              ? AppTheme.warningYellow
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                        tooltip: node.isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // More options button
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.darkBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _showMoreOptions(context, ref),
                        icon: const Icon(
                          Icons.more_horiz,
                          color: AppTheme.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'More options',
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // QR Code button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showNodeQrCode(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code, size: 20),
                        label: const Text(
                          'QR Code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Message button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendDirectMessage(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.message, size: 20),
                        label: const Text(
                          'Message',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                // Primary action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showNodeQrCode(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text(
                      'Share My Node',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Device power controls
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRebootConfirmation(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warningYellow,
                          side: BorderSide(
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.restart_alt, size: 20),
                        label: const Text(
                          'Reboot',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showShutdownConfirmation(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          side: BorderSide(
                            color: AppTheme.errorRed.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.power_settings_new, size: 20),
                        label: const Text(
                          'Shutdown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
