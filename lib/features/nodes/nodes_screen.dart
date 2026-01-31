import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/social_providers.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/gradient_border_container.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/skeleton_config.dart';
// import '../../core/widgets/verified_badge.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../services/share_link_service.dart';
import '../messaging/messaging_screen.dart';
import '../map/map_screen.dart';
import '../navigation/main_shell.dart';
import '../../providers/presence_providers.dart';
// import '../social/screens/profile_social_screen.dart';

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
  bool _showSectionHeaders = true;
  final TextEditingController _searchController = TextEditingController();

  /// Track node IDs that have already been seen/animated
  /// This allows new nodes to animate in while existing ones don't re-animate
  final Set<int> _seenNodeIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  PresenceConfidence _presenceForNode(
    Map<int, NodePresence> presenceMap,
    MeshNode node,
  ) {
    return presenceMap[node.nodeNum]?.confidence ?? node.presenceConfidence;
  }

  Duration? _lastHeardAgeForNode(
    Map<int, NodePresence> presenceMap,
    MeshNode node,
  ) {
    return presenceMap[node.nodeNum]?.timeSinceLastHeard ?? node.lastHeardAge;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final linkedNodeIds =
        ref.watch(linkedNodeIdsProvider).asData?.value ?? <int>[];
    final connectionStateAsync = ref.watch(connectionStateProvider);

    // Check if connected - used to show loading shimmer
    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (_, _) => false,
    );

    var nodesList = nodes.values.toList();

    // Apply filter
    nodesList = _applyFilter(nodesList, myNodeNum, linkedNodeIds, presenceMap);

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
    final activeCount = allNodes
        .where((n) => _presenceForNode(presenceMap, n).isActive)
        .length;
    final inactiveCount = allNodes
        .where((n) => _presenceForNode(presenceMap, n).isInactive)
        .length;
    final favoritesCount = allNodes.where((n) => n.isFavorite).length;
    final withPositionCount = allNodes
        .where((n) => n.latitude != null && n.longitude != null)
        .length;
    final recentlyDiscoveredCount = allNodes
        .where((n) => n.isRecentlyDiscovered)
        .length;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'nodes_overview',
        stepKeys: const {},
        child: GlassScaffold(
          leading: const HamburgerMenuButton(),
          centerTitle: true,
          titleWidget: Text(
            'Nodes (${nodes.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan Node QR',
              onPressed: () => Navigator.pushNamed(context, '/node-qr-scanner'),
            ),
            const DeviceStatusButton(),
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                switch (value) {
                  case 'settings':
                    Navigator.pushNamed(context, '/settings');
                  case 'help':
                    ref.read(helpProvider.notifier).startTour('nodes_overview');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Help',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          slivers: [
            // Pinned search and filter controls
            SliverPersistentHeader(
              pinned: true,
              delegate: _NodesControlsHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                activeFilter: _activeFilter,
                onFilterChanged: (filter) =>
                    setState(() => _activeFilter = filter),
                sortOrder: _sortOrder,
                onSortChanged: (order) => setState(() => _sortOrder = order),
                showSectionHeaders: _showSectionHeaders,
                onToggleSectionHeaders: () =>
                    setState(() => _showSectionHeaders = !_showSectionHeaders),
                nodeCount: nodes.length,
                activeCount: activeCount,
                inactiveCount: inactiveCount,
                favoritesCount: favoritesCount,
                withPositionCount: withPositionCount,
                recentlyDiscoveredCount: recentlyDiscoveredCount,
              ),
            ),
            // Node list content
            if (nodesList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: (isConnected && _activeFilter == NodeFilter.all)
                    ? _buildLoadingShimmer()
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.group,
                                size: 40,
                                color: context.textTertiary,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              _activeFilter == NodeFilter.all
                                  ? 'No nodes discovered yet'
                                  : 'No nodes match this filter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: context.textSecondary,
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
                      ),
              )
            else
              ..._buildNodeSlivers(
                nodesList,
                myNodeNum,
                linkedNodeIds,
                presenceMap,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNodeSlivers(
    List<MeshNode> nodesList,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap,
  ) {
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    // Find new nodes that haven't been seen yet for animation
    final newNodeIds = <int>[];
    for (final node in nodesList) {
      if (!_seenNodeIds.contains(node.nodeNum)) {
        newNodeIds.add(node.nodeNum);
      }
    }

    // Mark new nodes as seen
    if (newNodeIds.isNotEmpty) {
      _seenNodeIds.addAll(newNodeIds);
    }

    if (!_showSectionHeaders) {
      // Simple list without headers
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final node = nodesList[index];
            final isMyNode = node.nodeNum == myNodeNum;
            final isNewNode = newNodeIds.contains(node.nodeNum);

            // Only animate if it's a new node, use batch index for stagger
            final animIndex = isNewNode ? newNodeIds.indexOf(node.nodeNum) : 0;

            return Perspective3DSlide(
              key: ValueKey('node_${node.nodeNum}'),
              index: animIndex,
              direction: SlideDirection.left,
              enabled: animationsEnabled && isNewNode,
              child: _NodeCard(
                node: node,
                isMyNode: isMyNode,
                presenceConfidence: _presenceForNode(presenceMap, node),
                lastHeardAge: _lastHeardAgeForNode(presenceMap, node),
                animationsEnabled: animationsEnabled,
                onTap: () => _showNodeDetails(context, node, isMyNode),
                onLongPress: isMyNode
                    ? () => _showNodeLongPressMenu(context, node, isMyNode)
                    : null,
              ),
            );
          }, childCount: nodesList.length),
        ),
      ];
    }

    // Build grouped list with sticky section headers
    final sections = _groupNodesIntoSections(
      nodesList,
      myNodeNum,
      linkedNodeIds,
      presenceMap,
    );
    final nonEmptySections = sections.where((s) => s.nodes.isNotEmpty).toList();

    return [
      for (
        var sectionIndex = 0;
        sectionIndex < nonEmptySections.length;
        sectionIndex++
      ) ...[
        // Sticky header
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: nonEmptySections[sectionIndex].title,
            count: nonEmptySections[sectionIndex].nodes.length,
          ),
        ),
        // Section nodes
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final node = nonEmptySections[sectionIndex].nodes[index];
            final isMyNode = node.nodeNum == myNodeNum;
            final isNewNode = newNodeIds.contains(node.nodeNum);

            // Calculate animation index for new nodes across sections
            final animIndex = isNewNode ? newNodeIds.indexOf(node.nodeNum) : 0;

            return Perspective3DSlide(
              key: ValueKey('node_${node.nodeNum}'),
              index: animIndex,
              direction: SlideDirection.left,
              enabled: animationsEnabled && isNewNode,
              child: _NodeCard(
                node: node,
                isMyNode: isMyNode,
                presenceConfidence: _presenceForNode(presenceMap, node),
                lastHeardAge: _lastHeardAgeForNode(presenceMap, node),
                animationsEnabled: animationsEnabled,
                onTap: () => _showNodeDetails(context, node, isMyNode),
                onLongPress: isMyNode
                    ? () => _showNodeLongPressMenu(context, node, isMyNode)
                    : null,
              ),
            );
          }, childCount: nonEmptySections[sectionIndex].nodes.length),
        ),
      ],
    ];
  }

  List<_NodeSection> _groupNodesIntoSections(
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap,
  ) {
    switch (_sortOrder) {
      case NodeSortOrder.lastHeard:
        return _groupByStatus(nodes, myNodeNum, linkedNodeIds, presenceMap);
      case NodeSortOrder.name:
        return _groupByAlphabet(nodes, myNodeNum, linkedNodeIds);
      case NodeSortOrder.signalStrength:
        return _groupBySignal(nodes, myNodeNum, linkedNodeIds);
      case NodeSortOrder.batteryLevel:
        return _groupByBattery(nodes, myNodeNum, linkedNodeIds);
    }
  }

  List<_NodeSection> _groupByStatus(
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap,
  ) {
    final myNode = nodes.where((n) => n.nodeNum == myNodeNum).toList();
    // final linkedNodes = nodes
    //     .where(
    //       (n) => n.nodeNum != myNodeNum && linkedNodeIds.contains(n.nodeNum),
    //     )
    //     .toList();
    final active = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isActive,
        )
        .toList();
    final fading = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isFading,
        )
        .toList();
    final inactive = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isStale,
        )
        .toList();
    final unknown = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isUnknown,
        )
        .toList();

    return [
      if (myNode.isNotEmpty) _NodeSection('Your Device', myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      _NodeSection('Active', active),
      _NodeSection('Seen Recently', fading),
      _NodeSection('Inactive', inactive),
      _NodeSection('Unknown', unknown),
    ];
  }

  List<_NodeSection> _groupByAlphabet(
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
  ) {
    final myNode = nodes.where((n) => n.nodeNum == myNodeNum).toList();
    // final linkedNodes = nodes
    //     .where(
    //       (n) => n.nodeNum != myNodeNum && linkedNodeIds.contains(n.nodeNum),
    //     )
    //     .toList();
    final others = nodes
        .where(
          (n) => n.nodeNum != myNodeNum && !linkedNodeIds.contains(n.nodeNum),
        )
        .toList();

    final grouped = <String, List<MeshNode>>{};
    for (final node in others) {
      final firstChar = node.displayName.isNotEmpty
          ? node.displayName[0].toUpperCase()
          : '#';
      final key = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
      grouped.putIfAbsent(key, () => []).add(node);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return [
      if (myNode.isNotEmpty) _NodeSection('Your Device', myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      ...sortedKeys.map((key) => _NodeSection(key, grouped[key]!)),
    ];
  }

  List<_NodeSection> _groupBySignal(
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
  ) {
    final myNode = nodes.where((n) => n.nodeNum == myNodeNum).toList();
    // final linkedNodes = nodes
    //     .where(
    //       (n) => n.nodeNum != myNodeNum && linkedNodeIds.contains(n.nodeNum),
    //     )
    //     .toList();
    final others = nodes
        .where(
          (n) => n.nodeNum != myNodeNum && !linkedNodeIds.contains(n.nodeNum),
        )
        .toList();

    final strong = others.where((n) => (n.snr ?? -999) > 0).toList();
    final medium = others
        .where((n) => (n.snr ?? -999) <= 0 && (n.snr ?? -999) > -10)
        .toList();
    final weak = others
        .where((n) => (n.snr ?? -999) <= -10 && n.snr != null)
        .toList();
    final unknown = others.where((n) => n.snr == null).toList();

    return [
      if (myNode.isNotEmpty) _NodeSection('Your Device', myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      _NodeSection('Strong (>0 dB)', strong),
      _NodeSection('Medium (-10 to 0 dB)', medium),
      _NodeSection('Weak (<-10 dB)', weak),
      _NodeSection('Unknown', unknown),
    ];
  }

  List<_NodeSection> _groupByBattery(
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
  ) {
    final myNode = nodes.where((n) => n.nodeNum == myNodeNum).toList();
    // final linkedNodes = nodes
    //     .where(
    //       (n) => n.nodeNum != myNodeNum && linkedNodeIds.contains(n.nodeNum),
    //     )
    //     .toList();
    final others = nodes
        .where(
          (n) => n.nodeNum != myNodeNum && !linkedNodeIds.contains(n.nodeNum),
        )
        .toList();

    final charging = others.where((n) => (n.batteryLevel ?? -1) > 100).toList();
    final full = others
        .where(
          (n) => (n.batteryLevel ?? -1) >= 80 && (n.batteryLevel ?? -1) <= 100,
        )
        .toList();
    final good = others
        .where(
          (n) => (n.batteryLevel ?? -1) >= 50 && (n.batteryLevel ?? -1) < 80,
        )
        .toList();
    final low = others
        .where(
          (n) => (n.batteryLevel ?? -1) >= 20 && (n.batteryLevel ?? -1) < 50,
        )
        .toList();
    final critical = others
        .where((n) => (n.batteryLevel ?? -1) > 0 && (n.batteryLevel ?? -1) < 20)
        .toList();
    final unknown = others
        .where((n) => n.batteryLevel == null || n.batteryLevel == 0)
        .toList();

    return [
      if (myNode.isNotEmpty) _NodeSection('Your Device', myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      _NodeSection('Charging', charging),
      _NodeSection('Full (80-100%)', full),
      _NodeSection('Good (50-80%)', good),
      _NodeSection('Low (20-50%)', low),
      _NodeSection('Critical (<20%)', critical),
      _NodeSection('Unknown', unknown),
    ];
  }

  List<MeshNode> _applyFilter(
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap,
  ) {
    switch (_activeFilter) {
      case NodeFilter.all:
        return nodes;
      case NodeFilter.active:
        return nodes
            .where((n) => _presenceForNode(presenceMap, n).isActive)
            .toList();
      case NodeFilter.inactive:
        return nodes
            .where((n) => _presenceForNode(presenceMap, n).isInactive)
            .toList();
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

  void _showNodeLongPressMenu(
    BuildContext context,
    MeshNode node,
    bool isMyNode,
  ) {
    // Only show menu for the connected device (myNode)
    if (!isMyNode) return;

    HapticFeedback.mediumImpact();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    NodeAvatar(
                      text: node.avatarName,
                      color: context.accentColor,
                      size: 40,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.displayName,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Connected Device',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: context.border),
              // Disconnect option
              ListTile(
                leading: Icon(Icons.link_off_rounded, color: AppTheme.errorRed),
                title: const Text(
                  'Disconnect',
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _disconnectDevice();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _disconnectDevice() async {
    final transport = ref.read(transportProvider);
    await transport.disconnect();
    ref.read(connectedDeviceProvider.notifier).setState(null);
  }

  Widget _buildLoadingShimmer() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 8,
        itemBuilder: (context, index) => const SkeletonNodeCard(),
      ),
    );
  }
}

/// Filter options for the nodes list
enum NodeFilter {
  all,
  active,
  inactive,
  favorites,
  withPosition,
  recentlyDiscovered,
}

/// Sort order options for the nodes list
enum NodeSortOrder { lastHeard, name, signalStrength, batteryLevel }

/// Delegate for the pinned search bar and filter controls header
class _NodesControlsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final NodeFilter activeFilter;
  final ValueChanged<NodeFilter> onFilterChanged;
  final NodeSortOrder sortOrder;
  final ValueChanged<NodeSortOrder> onSortChanged;
  final bool showSectionHeaders;
  final VoidCallback onToggleSectionHeaders;
  final int nodeCount;
  final int activeCount;
  final int inactiveCount;
  final int favoritesCount;
  final int withPositionCount;
  final int recentlyDiscoveredCount;

  _NodesControlsHeaderDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.sortOrder,
    required this.onSortChanged,
    required this.showSectionHeaders,
    required this.onToggleSectionHeaders,
    required this.nodeCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.favoritesCount,
    required this.withPositionCount,
    required this.recentlyDiscoveredCount,
  });

  @override
  double get minExtent => 112; // Search bar + filter chips + divider

  @override
  double get maxExtent => 112;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: context.background,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Find a node',
                  hintStyle: TextStyle(color: context.textTertiary),
                  prefixIcon: Icon(Icons.search, color: context.textTertiary),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: context.textTertiary),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
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
          // Filter chips row with static controls at end
          SizedBox(
            height: 44,
            child: Row(
              children: [
                // Scrollable filter chips and sort button with edge fade
                Expanded(
                  child: EdgeFade.end(
                    fadeSize: 32,
                    fadeColor: context.background,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 16),
                      children: [
                        SectionFilterChip(
                          label: 'All',
                          count: nodeCount,
                          isSelected: activeFilter == NodeFilter.all,
                          onTap: () => onFilterChanged(NodeFilter.all),
                        ),
                        const SizedBox(width: 8),
                        SectionFilterChip(
                          label: 'Active',
                          count: activeCount,
                          isSelected: activeFilter == NodeFilter.active,
                          color: AccentColors.green,
                          onTap: () => onFilterChanged(NodeFilter.active),
                        ),
                        const SizedBox(width: 8),
                        SectionFilterChip(
                          label: 'Favorites',
                          count: favoritesCount,
                          isSelected: activeFilter == NodeFilter.favorites,
                          color: AppTheme.warningYellow,
                          icon: Icons.star,
                          onTap: () => onFilterChanged(NodeFilter.favorites),
                        ),
                        const SizedBox(width: 8),
                        SectionFilterChip(
                          label: 'With Position',
                          count: withPositionCount,
                          isSelected: activeFilter == NodeFilter.withPosition,
                          color: AccentColors.cyan,
                          icon: Icons.location_on,
                          onTap: () => onFilterChanged(NodeFilter.withPosition),
                        ),
                        const SizedBox(width: 8),
                        SectionFilterChip(
                          label: 'Inactive',
                          count: inactiveCount,
                          isSelected: activeFilter == NodeFilter.inactive,
                          color: context.textTertiary,
                          onTap: () => onFilterChanged(NodeFilter.inactive),
                        ),
                        const SizedBox(width: 8),
                        SectionFilterChip(
                          label: 'New',
                          count: recentlyDiscoveredCount,
                          isSelected:
                              activeFilter == NodeFilter.recentlyDiscovered,
                          color: AccentColors.purple,
                          icon: Icons.fiber_new,
                          onTap: () =>
                              onFilterChanged(NodeFilter.recentlyDiscovered),
                        ),
                        const SizedBox(width: 8),
                        _SortButton(
                          sortOrder: sortOrder,
                          onChanged: onSortChanged,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                // Static toggle at end
                const SizedBox(width: 8),
                SectionHeadersToggle(
                  enabled: showSectionHeaders,
                  onToggle: onToggleSectionHeaders,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: context.border.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _NodesControlsHeaderDelegate oldDelegate) {
    return searchQuery != oldDelegate.searchQuery ||
        activeFilter != oldDelegate.activeFilter ||
        sortOrder != oldDelegate.sortOrder ||
        showSectionHeaders != oldDelegate.showSectionHeaders ||
        nodeCount != oldDelegate.nodeCount ||
        activeCount != oldDelegate.activeCount ||
        inactiveCount != oldDelegate.inactiveCount ||
        favoritesCount != oldDelegate.favoritesCount ||
        withPositionCount != oldDelegate.withPositionCount ||
        recentlyDiscoveredCount != oldDelegate.recentlyDiscoveredCount;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: context.card,
        child: InkWell(
          onTap: () => _showSortMenu(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 14, color: context.textTertiary),
                SizedBox(width: 4),
                Text(
                  _sortLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height + 4),
      ancestor: overlay,
    );

    showMenu<NodeSortOrder>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        overlay.size.width - offset.dx - button.size.width,
        0,
      ),
      color: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _buildMenuItem(
          NodeSortOrder.lastHeard,
          'Most Recent',
          Icons.schedule,
          context,
        ),
        _buildMenuItem(
          NodeSortOrder.name,
          'Name (A-Z)',
          Icons.sort_by_alpha,
          context,
        ),
        _buildMenuItem(
          NodeSortOrder.signalStrength,
          'Signal Strength',
          Icons.signal_cellular_alt,
          context,
        ),
        _buildMenuItem(
          NodeSortOrder.batteryLevel,
          'Battery Level',
          Icons.battery_full,
          context,
        ),
      ],
    ).then((value) {
      if (value != null) {
        onChanged(value);
      }
    });
  }

  PopupMenuItem<NodeSortOrder> _buildMenuItem(
    NodeSortOrder value,
    String label,
    IconData icon,
    BuildContext context,
  ) {
    final isSelected = sortOrder == value;
    final accentColor = context.accentColor;
    return PopupMenuItem<NodeSortOrder>(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check : icon,
            size: 18,
            color: isSelected ? accentColor : context.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

/// Helper class for section grouping
class _NodeSection {
  final String title;
  final List<MeshNode> nodes;

  _NodeSection(this.title, this.nodes);
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
  final PresenceConfidence presenceConfidence;
  final Duration? lastHeardAge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool animationsEnabled;

  const _NodeCard({
    required this.node,
    required this.isMyNode,
    required this.presenceConfidence,
    required this.lastHeardAge,
    required this.onTap,
    this.onLongPress,
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
    final statusColor = _presenceColor(context, presenceConfidence);
    final statusText = presenceStatusText(presenceConfidence, lastHeardAge);
    final cardOpacity = isMyNode ? 1.0 : presenceOpacity(presenceConfidence);

    return BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      enable3DPress: animationsEnabled,
      tiltDegrees: 4.0,
      child: Opacity(
        opacity: cardOpacity,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: !isMyNode && !node.isFavorite
              ? BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border, width: 1),
                )
              : null,
          child: isMyNode
              ? GradientBorderContainer(
                  borderRadius: 12,
                  borderWidth: 2,
                  accentOpacity: 1.0,
                  backgroundColor: context.accentColor.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(16),
                  child: _buildCardContent(
                    context,
                    signalBars,
                    statusColor,
                    statusText,
                  ),
                )
              : node.isFavorite
              ? GradientBorderContainer(
                  borderRadius: 12,
                  borderWidth: 2,
                  accentOpacity: 1.0,
                  accentColor: AccentColors.yellow,
                  backgroundColor: context.card,
                  padding: const EdgeInsets.all(16),
                  child: _buildCardContent(
                    context,
                    signalBars,
                    statusColor,
                    statusText,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCardContent(
                    context,
                    signalBars,
                    statusColor,
                    statusText,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    int signalBars,
    Color statusColor,
    String statusText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        NodeAvatar(
          text: node.avatarName,
          color: isMyNode ? context.accentColor : _getAvatarColor(),
          size: 56,
          showOnlineIndicator: presenceConfidence.isActive,
          onlineStatus: presenceConfidence.isActive
              ? OnlineStatus.online
              : null,
          batteryLevel: node.batteryLevel,
          showBatteryBadge: true,
          border: isMyNode
              ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)
              : null,
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
                        : context.textTertiary,
                  ),
                  SizedBox(width: 8),
                  // Name
                  Flexible(
                    child: Text(
                      node.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
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
                      child: Text(
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
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: presenceConfidence.isActive
                              ? [
                                  statusColor,
                                  statusColor.withValues(alpha: 0.6),
                                ]
                              : [
                                  context.textTertiary,
                                  context.textTertiary.withValues(alpha: 0.6),
                                ],
                        ),
                        boxShadow: presenceConfidence.isActive
                            ? [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: presenceConfidence.isActive
                              ? statusColor.withValues(alpha: 0.3)
                              : context.textTertiary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message: kPresenceInferenceTooltip,
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 4),
              // Last heard
              if (node.lastHeard != null) ...[
                Row(
                  children: [
                    Icon(Icons.check, size: 14, color: context.accentColor),
                    SizedBox(width: 6),
                    Text(
                      _formatLastHeard(node.lastHeard!),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
              ],
              // Role and GPS status
              Row(
                children: [
                  if (node.role != null) ...[
                    Icon(
                      Icons.smartphone,
                      size: 14,
                      color: context.textTertiary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      node.role!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.gps_fixed,
                    size: 14,
                    color: node.hasPosition
                        ? context.accentColor
                        : context.textTertiary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    node.hasPosition ? 'GPS' : 'No GPS',
                    style: TextStyle(
                      fontSize: 12,
                      color: node.hasPosition
                          ? context.accentColor
                          : context.textTertiary,
                    ),
                  ),
                ],
              ),
              // Distance & heading
              if (node.distance != null) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 14, color: context.textTertiary),
                    SizedBox(width: 6),
                    Text(
                      _formatDistance(node.distance),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
              // Logs indicators
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.article, size: 14, color: context.textTertiary),
                  SizedBox(width: 4),
                  Text(
                    'Logs:',
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.message, size: 14, color: context.textTertiary),
                  SizedBox(width: 8),
                  Icon(Icons.place, size: 14, color: context.textTertiary),
                ],
              ),
              // Signal bars
              if (node.rssi != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 14,
                      color: context.textTertiary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Signal Good',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
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
                                : context.textTertiary.withValues(alpha: 0.3),
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
                  Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.volume_off,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
                  ),
                if (node.isFavorite)
                  const Icon(Icons.star, color: AccentColors.yellow, size: 24)
                else if (!node.isIgnored)
                  const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 8),
            Icon(Icons.chevron_right, color: context.textTertiary, size: 24),
          ],
        ),
      ],
    );
  }

  Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return context.accentColor;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
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
          SizedBox(height: 24),

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
              color: context.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tag, size: 16, color: context.textTertiary),
                SizedBox(width: 8),
                Text(
                  'Node ID: ${node.nodeNum.toRadixString(16).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
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
          const SizedBox(height: 12),
          // Share via link button (web-compatible)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _shareNodeViaLink(context, node);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.accentColor,
                side: BorderSide(
                  color: context.accentColor.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.share, size: 20),
              label: const Text(
                'Share via Link',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Share a node via a web link (works for both Android and iOS recipients)
  Future<void> _shareNodeViaLink(BuildContext context, MeshNode node) async {
    try {
      final shareLinkService = ref.read(shareLinkServiceProvider);
      await shareLinkService.shareNode(
        node: node,
        description:
            '${node.role ?? 'Mesh Node'} • ${node.hardwareModel ?? 'Unknown Hardware'}',
      );
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share node: $e');
      }
    }
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
    final deviceFavorites = ref.read(deviceFavoritesProvider).value;

    try {
      if (node.isFavorite) {
        await protocol.removeFavoriteNode(node.nodeNum);
        // Persist to DeviceFavoritesService
        await deviceFavorites?.removeFavorite(node.nodeNum);
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
        // Persist to DeviceFavoritesService
        await deviceFavorites?.addFavorite(node.nodeNum);
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
    final deviceFavorites = ref.read(deviceFavoritesProvider).value;

    try {
      if (node.isIgnored) {
        await protocol.removeIgnoredNode(node.nodeNum);
        // Persist to DeviceFavoritesService
        await deviceFavorites?.removeIgnored(node.nodeNum);
        // Update local state
        nodesNotifier.addOrUpdateNode(node.copyWith(isIgnored: false));
        if (context.mounted) {
          showSuccessSnackBar(context, '${node.displayName} unmuted');
        }
      } else {
        await protocol.setIgnoredNode(node.nodeNum);
        // Persist to DeviceFavoritesService
        await deviceFavorites?.addIgnored(node.nodeNum);
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
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restart_alt, color: AppTheme.warningYellow, size: 24),
            SizedBox(width: 12),
            Text(
              'Reboot Device',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reboot your Meshtastic device. The app will automatically reconnect once the device restarts.',
          style: TextStyle(
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
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
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.power_settings_new, color: AppTheme.errorRed, size: 24),
            SizedBox(width: 12),
            Text(
              'Shutdown Device',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'This will turn off your Meshtastic device. You will need to physically power it back on to reconnect.',
          style: TextStyle(
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
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
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Node',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Remove ${node.displayName} from the node database? This will remove the node from your local device.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
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
                // Brief delay after sending command
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

  void _requestUserInfo(BuildContext context, MeshNode node) async {
    Navigator.pop(context);

    final protocol = ref.read(protocolServiceProvider);

    try {
      // Request node info to refresh PKI keys and user data
      await protocol.requestNodeInfo(node.nodeNum);

      if (context.mounted) {
        showInfoSnackBar(
          context,
          'User info requested from ${node.displayName}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request user info: $e');
      }
    }
  }

  void _configureRemotely(BuildContext context, MeshNode node) {
    Navigator.pop(context);

    // Set the remote admin target
    ref
        .read(remoteAdminProvider.notifier)
        .setTarget(node.nodeNum, node.displayName);

    // Navigate to settings
    Navigator.pushNamed(context, '/settings');

    // Show info about remote admin
    showInfoSnackBar(
      context,
      'Remote admin enabled for ${node.displayName}. Device settings will now configure this node.',
    );
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
            leading: Icon(Icons.refresh, color: context.accentColor),
            title: Text(
              'Request User Info',
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            subtitle: Text(
              'Refresh node info and encryption keys',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              _requestUserInfo(context, node);
            },
          ),
          ListTile(
            leading: Icon(Icons.swap_horiz, color: context.accentColor),
            title: Text(
              'Exchange Positions',
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            subtitle: Text(
              'Request GPS position from this node',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
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
                  : context.textSecondary,
            ),
            title: Text(
              node.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
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
              color: node.isIgnored ? AppTheme.errorRed : context.textSecondary,
            ),
            title: Text(
              node.isIgnored ? 'Unmute Node' : 'Mute Node',
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            subtitle: Text(
              node.isIgnored
                  ? 'Receive messages from this node'
                  : 'Hide messages from this node',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleIgnored(context, node);
            },
          ),
          if (node.hasPosition)
            ListTile(
              leading: Icon(Icons.location_on, color: context.textSecondary),
              title: Text(
                'Set as Fixed Position',
                style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
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
                fontFamily: AppTheme.fontFamily,
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
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: AutoScrollText(
                            node.displayName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
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
                            child: Text(
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
                    SizedBox(height: 4),
                    Text(
                      '!${node.nodeNum.toRadixString(16)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                        fontFamily: AppTheme.fontFamily,
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
                icon: Icon(Icons.qr_code, color: context.textSecondary),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            height: 1,
            color: context.border.withValues(alpha: 0.3),
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
                  // PKI / Encryption status
                  InfoTableRow(
                    icon: node.hasPublicKey ? Icons.lock : Icons.lock_open,
                    iconColor: node.hasPublicKey
                        ? context.accentColor
                        : context.textTertiary,
                    label: 'Encryption',
                    value: node.hasPublicKey ? 'PKI Enabled' : 'No Public Key',
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          //
          // Linked Social Profile section (shows if user has linked this node)
          // if (!isMyNode) _LinkedProfileSection(nodeNum: node.nodeNum),

          // Remote Administration button (only for nodes with PKI)
          if (!isMyNode && node.hasPublicKey)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _configureRemotely(context, node),
                  icon: const Icon(Icons.admin_panel_settings, size: 20),
                  label: const Text('Configure Remotely'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentColor,
                    side: BorderSide(color: context.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

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
                        border: Border.all(color: context.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isTogglingFavorite
                          ? Padding(
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
                                    : context.textSecondary,
                                size: 22,
                              ),
                              tooltip: node.isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(),
                            ),
                    ),
                    SizedBox(width: 8),
                    // Mute button
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isTogglingMute
                          ? Padding(
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
                                    : context.textSecondary,
                                size: 22,
                              ),
                              tooltip: node.isIgnored
                                  ? 'Unmute node'
                                  : 'Mute node',
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(),
                            ),
                    ),
                    SizedBox(width: 8),
                    // More options button
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _showMoreOptions(context, node),
                        icon: Icon(
                          Icons.more_horiz,
                          color: context.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'More options',
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    SizedBox(width: 8),
                    // QR Code button
                    IconButton(
                      onPressed: () => _showNodeQrCode(context, node),
                      icon: Icon(
                        Icons.qr_code,
                        color: context.textSecondary,
                        size: 22,
                      ),
                      tooltip: 'QR Code',
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 8),
                    // Message button
                    IconButton(
                      onPressed: () => _sendDirectMessage(context, node),
                      icon: Icon(
                        Icons.message,
                        color: context.textSecondary,
                        size: 22,
                      ),
                      tooltip: 'QR Code',
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(),
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

// Re-enable when social features are restored
// Widget to show linked social profile if a user has linked this node
// class _LinkedProfileSection extends ConsumerWidget {
//   const _LinkedProfileSection({required this.nodeNum});
//
//   final int nodeNum;
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final profileAsync = ref.watch(profileByNodeIdProvider(nodeNum));
//
//     return profileAsync.when(
//       data: (profile) {
//         if (profile == null) return const SizedBox.shrink();
//
//         return Padding(
//           padding: const EdgeInsets.only(bottom: 16),
//           child: Container(
//             decoration: BoxDecoration(
//               color: context.accentColor.withValues(alpha: 0.1),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(
//                 color: context.accentColor.withValues(alpha: 0.3),
//               ),
//             ),
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 // Avatar
//                 CircleAvatar(
//                   radius: 24,
//                   backgroundImage: profile.avatarUrl != null
//                       ? NetworkImage(profile.avatarUrl!)
//                       : null,
//                   backgroundColor: context.accentColor.withValues(alpha: 0.2),
//                   child: profile.avatarUrl == null
//                       ? Text(
//                           profile.displayName.isNotEmpty
//                               ? profile.displayName[0].toUpperCase()
//                               : '?',
//                           style: TextStyle(
//                             color: context.accentColor,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         )
//                       : null,
//                 ),
//                 const SizedBox(width: 12),
//                 // Profile info
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Flexible(
//                             child: Text(
//                               profile.displayName,
//                               style: TextStyle(
//                                 color: context.textPrimary,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 15,
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           if (profile.isVerified) ...[
//                             const SizedBox(width: 4),
//                             const SimpleVerifiedBadge(size: 16),
//                           ],
//                         ],
//                       ),
//                       if (profile.callsign != null) ...[
//                         const SizedBox(height: 2),
//                         Text(
//                           profile.callsign!,
//                           style: TextStyle(
//                             color: context.textSecondary,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                       const SizedBox(height: 4),
//                       Text(
//                         '${profile.followerCount} followers • ${profile.postCount} posts',
//                         style: TextStyle(
//                           color: context.textTertiary,
//                           fontSize: 11,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // View Profile button
//                 FilledButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => ProfileSocialScreen(userId: profile.id),
//                       ),
//                     );
//                   },
//                   style: FilledButton.styleFrom(
//                     backgroundColor: context.accentColor,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 10,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                   ),
//                   child: const Text(
//                     'View',
//                     style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//       loading: () => const SizedBox.shrink(),
//       error: (_, _) => const SizedBox.shrink(),
//     );
//   }
// }
