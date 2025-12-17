import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/node_avatar.dart';
import '../messaging/messaging_screen.dart';
import '../map/map_screen.dart';
import '../navigation/main_shell.dart';

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
  if (level > 100) return AccentColors.green; // Charging
  if (level >= 50) return AccentColors.green;
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
  NodeFilter _activeFilter = NodeFilter.all;
  NodeSortOrder _sortOrder = NodeSortOrder.lastHeard;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    var nodesList = nodes.values.toList();

    // Apply filter
    nodesList = _applyFilter(nodesList, myNodeNum);

    // Apply sort
    nodesList = _applySort(nodesList, myNodeNum);

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      nodesList = nodesList.where((node) {
        final query = _searchQuery.toLowerCase();
        return node.displayName.toLowerCase().contains(query) ||
            node.userId?.toLowerCase().contains(query) == true ||
            node.nodeNum.toString().contains(query);
      }).toList();
    }

    // Count nodes by filter for badges
    final allNodes = nodes.values.toList();
    final onlineCount = allNodes.where((n) => n.isOnline).length;
    final favoritesCount = allNodes.where((n) => n.isFavorite).length;
    final withPositionCount = allNodes
        .where((n) => n.latitude != null && n.longitude != null)
        .length;
    final recentlyDiscoveredCount = allNodes
        .where((n) => n.isRecentlyDiscovered)
        .length;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          leading: const HamburgerMenuButton(),
          centerTitle: true,
          title: Text(
            'Nodes (${nodes.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan Node QR',
              onPressed: () => Navigator.pushNamed(context, '/node-qr-scanner'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Find a node',
                    hintStyle: const TextStyle(color: AppTheme.textTertiary),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.textTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppTheme.textTertiary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            // Filter chips row
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'All',
                    count: nodes.length,
                    isSelected: _activeFilter == NodeFilter.all,
                    onTap: () => setState(() => _activeFilter = NodeFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Online',
                    count: onlineCount,
                    isSelected: _activeFilter == NodeFilter.online,
                    color: AccentColors.green,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.online),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Favorites',
                    count: favoritesCount,
                    isSelected: _activeFilter == NodeFilter.favorites,
                    color: AppTheme.warningYellow,
                    icon: Icons.star,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.favorites),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'With Position',
                    count: withPositionCount,
                    isSelected: _activeFilter == NodeFilter.withPosition,
                    color: AccentColors.cyan,
                    icon: Icons.location_on,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.withPosition),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Offline',
                    count: nodes.length - onlineCount,
                    isSelected: _activeFilter == NodeFilter.offline,
                    color: AppTheme.textTertiary,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.offline),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'New',
                    count: recentlyDiscoveredCount,
                    isSelected: _activeFilter == NodeFilter.recentlyDiscovered,
                    color: AccentColors.purple,
                    icon: Icons.fiber_new,
                    onTap: () => setState(
                      () => _activeFilter = NodeFilter.recentlyDiscovered,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sort dropdown
                  _SortButton(
                    sortOrder: _sortOrder,
                    onChanged: (order) => setState(() => _sortOrder = order),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Divider
            Container(
              height: 1,
              color: AppTheme.darkBorder.withValues(alpha: 0.3),
            ),
            // Node list
            Expanded(
              child: nodesList.isEmpty
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
                          Text(
                            _activeFilter == NodeFilter.all
                                ? 'No nodes discovered yet'
                                : 'No nodes match this filter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (_activeFilter != NodeFilter.all) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => setState(
                                () => _activeFilter = NodeFilter.all,
                              ),
                              child: const Text('Show all nodes'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: nodesList.length,
                      itemBuilder: (context, index) {
                        final node = nodesList[index];
                        final isMyNode = node.nodeNum == myNodeNum;
                        final animationsEnabled = ref.watch(
                          animationsEnabledProvider,
                        );

                        return Perspective3DSlide(
                          index: index,
                          direction: SlideDirection.left,
                          enabled: animationsEnabled,
                          child: _NodeCard(
                            node: node,
                            isMyNode: isMyNode,
                            animationsEnabled: animationsEnabled,
                            onTap: () =>
                                _showNodeDetails(context, node, isMyNode),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<MeshNode> _applyFilter(List<MeshNode> nodes, int? myNodeNum) {
    switch (_activeFilter) {
      case NodeFilter.all:
        return nodes;
      case NodeFilter.online:
        return nodes.where((n) => n.isOnline).toList();
      case NodeFilter.offline:
        return nodes.where((n) => !n.isOnline).toList();
      case NodeFilter.favorites:
        return nodes.where((n) => n.isFavorite).toList();
      case NodeFilter.withPosition:
        return nodes
            .where((n) => n.latitude != null && n.longitude != null)
            .toList();
      case NodeFilter.recentlyDiscovered:
        return nodes.where((n) => n.isRecentlyDiscovered).toList();
    }
  }

  List<MeshNode> _applySort(List<MeshNode> nodes, int? myNodeNum) {
    final sorted = List<MeshNode>.from(nodes);
    sorted.sort((a, b) {
      // My node always first
      if (a.nodeNum == myNodeNum) return -1;
      if (b.nodeNum == myNodeNum) return 1;

      switch (_sortOrder) {
        case NodeSortOrder.lastHeard:
          // Favorites second when sorting by last heard
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          if (a.lastHeard == null) return 1;
          if (b.lastHeard == null) return -1;
          return b.lastHeard!.compareTo(a.lastHeard!);

        case NodeSortOrder.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );

        case NodeSortOrder.signalStrength:
          final aSnr = a.snr ?? -999;
          final bSnr = b.snr ?? -999;
          return bSnr.compareTo(aSnr); // Higher is better

        case NodeSortOrder.batteryLevel:
          final aBat = a.batteryLevel ?? -1;
          final bBat = b.batteryLevel ?? -1;
          return bBat.compareTo(aBat); // Higher is better
      }
    });
    return sorted;
  }

  void _showNodeDetails(BuildContext context, MeshNode node, bool isMyNode) {
    showNodeDetailsSheet(context, node, isMyNode);
  }
}

/// Filter options for the nodes list
enum NodeFilter {
  all,
  online,
  offline,
  favorites,
  withPosition,
  recentlyDiscovered,
}

/// Sort order options for the nodes list
enum NodeSortOrder { lastHeard, name, signalStrength, batteryLevel }

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryBlue;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.5)
                : AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? chipColor : AppTheme.textTertiary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.3)
                    : AppTheme.darkBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? chipColor : AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sort button with dropdown
class _SortButton extends StatelessWidget {
  final NodeSortOrder sortOrder;
  final ValueChanged<NodeSortOrder> onChanged;

  const _SortButton({required this.sortOrder, required this.onChanged});

  String get _sortLabel {
    switch (sortOrder) {
      case NodeSortOrder.lastHeard:
        return 'Recent';
      case NodeSortOrder.name:
        return 'Name';
      case NodeSortOrder.signalStrength:
        return 'Signal';
      case NodeSortOrder.batteryLevel:
        return 'Battery';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NodeSortOrder>(
      initialValue: sortOrder,
      onSelected: onChanged,
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 14, color: AppTheme.textTertiary),
            const SizedBox(width: 4),
            Text(
              _sortLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildMenuItem(NodeSortOrder.lastHeard, 'Most Recent', Icons.schedule),
        _buildMenuItem(NodeSortOrder.name, 'Name (A-Z)', Icons.sort_by_alpha),
        _buildMenuItem(
          NodeSortOrder.signalStrength,
          'Signal Strength',
          Icons.signal_cellular_alt,
        ),
        _buildMenuItem(
          NodeSortOrder.batteryLevel,
          'Battery Level',
          Icons.battery_full,
        ),
      ],
    );
  }

  PopupMenuItem<NodeSortOrder> _buildMenuItem(
    NodeSortOrder value,
    String label,
    IconData icon,
  ) {
    final isSelected = sortOrder == value;
    return PopupMenuItem<NodeSortOrder>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.textTertiary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryBlue : Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check, size: 18, color: AppTheme.primaryBlue),
        ],
      ),
    );
  }
}

/// Shows the node details bottom sheet. Can be called from any screen.
void showNodeDetailsSheet(BuildContext context, MeshNode node, bool isMyNode) {
  AppBottomSheet.show(
    context: context,
    padding: EdgeInsets.zero,
    child: NodeDetailsSheet(node: node, isMyNode: isMyNode),
  );
}

class _NodeCard extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final VoidCallback onTap;
  final bool animationsEnabled;

  const _NodeCard({
    required this.node,
    required this.isMyNode,
    required this.onTap,
    this.animationsEnabled = true,
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

    return BouncyTap(
      onTap: onTap,
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      enable3DPress: animationsEnabled,
      tiltDegrees: 4.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isMyNode
              ? context.accentColor.withValues(alpha: 0.08)
              : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyNode
                ? context.accentColor.withValues(alpha: 0.5)
                : AppTheme.darkBorder,
            width: isMyNode ? 1.5 : 1,
          ),
        ),
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
                      NodeAvatar(
                        text: node.avatarName,
                        color: isMyNode
                            ? context.accentColor
                            : _getAvatarColor(),
                        size: 56,
                        border: isMyNode
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              )
                            : null,
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
                                color: context.accentColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 12,
                              color: context.accentColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // PWD/Battery indicator
                  if (node.role != null || node.batteryLevel != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (node.role == 'CLIENT')
                          Icon(
                            Icons.bluetooth,
                            size: 14,
                            color: context.accentColor,
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
                              ),
                            ),
                        ],
                      ],
                    ),
                ],
              ),
              SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Lock icon (locked = has PKI public key)
                        Icon(
                          node.hasPublicKey ? Icons.lock : Icons.lock_open,
                          size: 16,
                          color: node.hasPublicKey
                              ? context.accentColor
                              : AppTheme.textTertiary,
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
                            ),
                          ),
                        ),
                        // "You" badge
                        if (isMyNode) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,

                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 6),
                    // Status - show "This Device" for your own node
                    if (isMyNode)
                      Row(
                        children: [
                          Icon(
                            Icons.smartphone,
                            size: 14,
                            color: context.accentColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'This Device',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.accentColor,
                              fontWeight: FontWeight.w500,
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
                                ? context.accentColor
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            node.isOnline ? 'Connected' : 'Offline',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 4),
                    // Last heard
                    if (node.lastHeard != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 14,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatLastHeard(node.lastHeard!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          SizedBox(width: 12),
                        ],
                        Icon(
                          Icons.gps_fixed,
                          size: 14,
                          color: node.hasPosition
                              ? context.accentColor
                              : AppTheme.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          node.hasPosition ? 'GPS' : 'No GPS',
                          style: TextStyle(
                            fontSize: 12,
                            color: node.hasPosition
                                ? context.accentColor
                                : AppTheme.textTertiary,
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
                            ),
                          ),
                          SizedBox(width: 12),
                          // Signal strength bars
                          Row(
                            children: List.generate(4, (i) {
                              return Container(
                                margin: const EdgeInsets.only(right: 3),
                                width: 4,
                                height: 12 + (i * 3.0),
                                decoration: BoxDecoration(
                                  color: i < signalBars
                                      ? context.accentColor
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
              // Status icons & chevron
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (node.isIgnored)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.volume_off,
                            color: AppTheme.errorRed,
                            size: 20,
                          ),
                        ),
                      if (node.isFavorite)
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD700),
                          size: 24,
                        )
                      else if (!node.isIgnored)
                        const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
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
    );
  }
}

/// Node details bottom sheet - can be used from any screen
class NodeDetailsSheet extends ConsumerStatefulWidget {
  final MeshNode node;
  final bool isMyNode;

  const NodeDetailsSheet({
    super.key,
    required this.node,
    required this.isMyNode,
  });

  @override
  ConsumerState<NodeDetailsSheet> createState() => _NodeDetailsSheetState();
}

class _NodeDetailsSheetState extends ConsumerState<NodeDetailsSheet> {
  bool _isTogglingFavorite = false;
  bool _isTogglingMute = false;

  MeshNode get _initialNode => widget.node;
  bool get isMyNode => widget.isMyNode;

  Color _getAvatarColor(MeshNode node) {
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

  void _showNodeQrCode(BuildContext context, MeshNode node) {
    // Create a shareable node info JSON
    final nodeInfo = {
      'nodeNum': node.nodeNum,
      'longName': node.longName ?? node.displayName,
      'shortName': node.avatarName,
      if (node.userId != null) 'userId': node.userId,
      if (node.hasPosition) 'lat': node.latitude,
      if (node.hasPosition) 'lon': node.longitude,
    };
    final nodeJson = jsonEncode(nodeInfo);
    final nodeUrl = 'socialmesh://node/${base64Encode(utf8.encode(nodeJson))}';

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            icon: Icons.qr_code,
            title: node.displayName,
            subtitle: 'Scan to add this node',
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
                const Icon(Icons.tag, size: 16, color: AppTheme.textTertiary),
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
                  ClipboardData(text: '!${node.nodeNum.toRadixString(16)}'),
                );
                Navigator.pop(context);
                showSuccessSnackBar(context, 'Node info copied');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy, size: 20),
              label: const Text(
                'Copy Node ID',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendDirectMessage(BuildContext context, MeshNode node) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: node.nodeNum,
          title: node.displayName,
          avatarColor: node.avatarColor,
        ),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, MeshNode node) async {
    if (_isTogglingFavorite) return;

    setState(() => _isTogglingFavorite = true);

    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);

    try {
      if (node.isFavorite) {
        await protocol.removeFavoriteNode(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: false));
        if (context.mounted) {
          showSuccessSnackBar(
            context,
            '${node.displayName} removed from favorites',
          );
        }
      } else {
        await protocol.setFavoriteNode(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: true));
        if (context.mounted) {
          showSuccessSnackBar(
            context,
            '${node.displayName} added to favorites',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to update favorite: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingFavorite = false);
      }
    }
  }

  void _toggleIgnored(BuildContext context, MeshNode node) async {
    if (_isTogglingMute) return;

    // Check connection state first
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(
        context,
        'Cannot change mute status: Device not connected',
      );
      return;
    }

    setState(() => _isTogglingMute = true);

    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);

    try {
      if (node.isIgnored) {
        await protocol.removeIgnoredNode(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isIgnored: false));
        if (context.mounted) {
          showSuccessSnackBar(context, '${node.displayName} unmuted');
        }
      } else {
        await protocol.setIgnoredNode(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isIgnored: true));
        if (context.mounted) {
          showSuccessSnackBar(context, '${node.displayName} muted');
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to update mute status: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingMute = false);
      }
    }
  }

  void _showRebootConfirmation(BuildContext context) {
    // Check connection state before showing reboot dialog
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot reboot: Device not connected');
      return;
    }

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
              ),
            ),
          ],
        ),
        content: const Text(
          'This will reboot your Meshtastic device. The app will automatically reconnect once the device restarts.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'JetBrainsMono',
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
                await protocol.reboot();
                if (context.mounted) {
                  showInfoSnackBar(context, 'Device is rebooting...');
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, 'Failed to reboot: $e');
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

  void _showShutdownConfirmation(BuildContext context) {
    // Check connection state before showing shutdown dialog
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot shutdown: Device not connected');
      return;
    }

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
              ),
            ),
          ],
        ),
        content: const Text(
          'This will turn off your Meshtastic device. You will need to physically power it back on to reconnect.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'JetBrainsMono',
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
                await protocol.shutdown();
                if (context.mounted) {
                  showInfoSnackBar(context, 'Device is shutting down...');
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, 'Failed to shutdown: $e');
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

  void _removeNode(BuildContext context, MeshNode node) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Node',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Remove ${node.displayName} from the node database? This will remove the node from your local device.',
          style: const TextStyle(color: AppTheme.textSecondary),
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
              final nodesNotifier = ref.read(nodesProvider.notifier);

              try {
                // Send remove command to device
                await protocol.removeNode(node.nodeNum);

                // Remove from local state/storage immediately
                // (like Meshtastic iOS does after sending the command)
                nodesNotifier.removeNode(node.nodeNum);

                if (context.mounted) {
                  showSuccessSnackBar(context, '${node.displayName} removed');
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, 'Failed to remove node: $e');
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

  void _setFixedPosition(BuildContext context, MeshNode node) async {
    if (!node.hasPosition) {
      showInfoSnackBar(context, 'Node has no position data');
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
        showSuccessSnackBar(
          context,
          'Fixed position set to ${node.displayName}\'s location',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to set fixed position: $e');
      }
    }
  }

  void _exchangePositions(BuildContext context, MeshNode node) async {
    Navigator.pop(context);

    final protocol = ref.read(protocolServiceProvider);

    try {
      // Request position from the target node
      await protocol.requestPosition(node.nodeNum);

      if (context.mounted) {
        showInfoSnackBar(
          context,
          'Position requested from ${node.displayName}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request position: $e');
      }
    }
  }

  void _showMoreOptions(BuildContext context, MeshNode node) {
    AppBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.swap_horiz, color: context.accentColor),
            title: const Text(
              'Exchange Positions',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            subtitle: const Text(
              'Request GPS position from this node',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              _exchangePositions(context, node);
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
                fontFamily: 'JetBrainsMono',
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleFavorite(context, node);
            },
          ),
          ListTile(
            leading: Icon(
              node.isIgnored ? Icons.volume_off : Icons.volume_up,
              color: node.isIgnored
                  ? AppTheme.errorRed
                  : AppTheme.textSecondary,
            ),
            title: Text(
              node.isIgnored ? 'Unmute Node' : 'Mute Node',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            subtitle: Text(
              node.isIgnored
                  ? 'Receive messages from this node'
                  : 'Hide messages from this node',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleIgnored(context, node);
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
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _setFixedPosition(context, node);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
            title: const Text(
              'Remove Node',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _removeNode(context, node);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    // Watch the nodes provider to get latest state
    final nodesMap = ref.watch(nodesProvider);
    final node = nodesMap[_initialNode.nodeNum] ?? _initialNode;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NodeAvatar(
                text: node.avatarName,
                color: isMyNode ? context.accentColor : _getAvatarColor(node),
                size: 64,
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
                            ),
                          ),
                        ),
                        if (isMyNode) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
              // Map button (if node has GPS)
              if (node.hasPosition)
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
                      ),
                    );
                  },
                  icon: Icon(Icons.map, color: context.accentColor),
                ),
              // QR code button
              IconButton(
                onPressed: () => _showNodeQrCode(context, node),
                icon: const Icon(Icons.qr_code, color: AppTheme.textSecondary),
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
                      child: _isTogglingFavorite
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.warningYellow,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: () => _toggleFavorite(context, node),
                              icon: Icon(
                                node.isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
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
                    // Mute button
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.darkBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isTogglingMute
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: () => _toggleIgnored(context, node),
                              icon: Icon(
                                node.isIgnored
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: node.isIgnored
                                    ? AppTheme.errorRed
                                    : AppTheme.textSecondary,
                                size: 22,
                              ),
                              tooltip: node.isIgnored
                                  ? 'Unmute node'
                                  : 'Mute node',
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
                        onPressed: () => _showMoreOptions(context, node),
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
                        onPressed: () => _showNodeQrCode(context, node),
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
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Message button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendDirectMessage(context, node),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentColor,
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
                    onPressed: () => _showNodeQrCode(context, node),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentColor,
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
                        onPressed: () => _showRebootConfirmation(context),
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
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showShutdownConfirmation(context),
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
