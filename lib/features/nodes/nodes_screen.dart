// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/gradient_border_container.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../core/widgets/skeleton_config.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/presence_providers.dart';
import '../../providers/social_providers.dart';
import '../../utils/presence_utils.dart';
import '../../utils/time_format.dart';
import '../../utils/timestamp_validation.dart';
import '../../utils/uptime_formatter.dart';
import '../../core/constants.dart';
import '../aether/providers/aether_flight_matcher_provider.dart';
import '../aether/widgets/aether_flight_match_card.dart';
import '../navigation/main_shell.dart';
import 'node_detail_screen.dart';
import 'widgets/nodes_legend_sheet.dart';

class NodesScreen extends ConsumerStatefulWidget {
  const NodesScreen({super.key});

  @override
  ConsumerState<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends ConsumerState<NodesScreen>
    with LifecycleSafeMixin<NodesScreen> {
  String _searchQuery = '';
  NodeFilter _activeFilter = NodeFilter.all;
  NodeSortOrder _sortOrder = NodeSortOrder.lastHeard;
  bool _showSectionHeaders = true;
  bool _compactView = false;
  final TextEditingController _searchController = TextEditingController();

  /// Track node IDs that have already been seen/animated
  /// This allows new nodes to animate in while existing ones don't re-animate
  final Set<int> _seenNodeIds = {};

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!mounted) return;
    safeSetState(() => _compactView = settings.nodeViewModeIndex == 1);
  }

  Future<void> _toggleViewMode() async {
    final newValue = !_compactView;
    safeSetState(() => _compactView = newValue);
    final settings = await ref.read(settingsServiceProvider.future);
    if (!mounted) return;
    await settings.setNodeViewModeIndex(newValue ? 1 : 0);
  }

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

  /// Whether a node is **online** — heard within the Meshtastic firmware
  /// online window (2 h).  Much broader than [PresenceConfidence.isActive]
  /// (2 min) and matches what the device screen reports as "online".
  bool _isOnlineNode(Map<int, NodePresence> presenceMap, MeshNode node) {
    final presence = presenceMap[node.nodeNum];
    if (presence != null) return presence.isOnline;
    return PresenceCalculator.isOnline(node.lastHeard, now: DateTime.now());
  }

  Duration? _lastHeardAgeForNode(
    Map<int, NodePresence> presenceMap,
    MeshNode node,
  ) {
    return presenceMap[node.nodeNum]?.timeSinceLastHeard ?? node.lastHeardAge;
  }

  Widget _buildNodeItem({
    required MeshNode node,
    required bool isMyNode,
    required Map<int, NodePresence> presenceMap,
    required bool animationsEnabled,
  }) {
    final presence = _presenceForNode(presenceMap, node);
    final lastHeardAge = _lastHeardAgeForNode(presenceMap, node);

    if (_compactView) {
      return _CompactNodeTile(
        node: node,
        isMyNode: isMyNode,
        presenceConfidence: presence,
        lastHeardAge: lastHeardAge,
        onTap: () => _showNodeDetails(context, node, isMyNode),
      );
    }

    return _NodeCard(
      node: node,
      isMyNode: isMyNode,
      presenceConfidence: presence,
      lastHeardAge: lastHeardAge,
      animationsEnabled: animationsEnabled,
      onTap: () => _showNodeDetails(context, node, isMyNode),
      onLongPress: isMyNode
          ? () => _showNodeLongPressMenu(context, node, isMyNode)
          : null,
    );
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

    // Watch discovery cooldown so skeletons disappear after the window expires
    // (default 3 min). Without this, a factory-reset device with no neighbors
    // would show "Discovering" skeletons forever.
    final discoveryCooldown = ref.watch(nodeDiscoveryCooldownProvider);
    final isInDiscoveryCooldown = discoveryCooldown.isInCooldown;

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
            node.shortName?.toLowerCase().contains(query) == true ||
            node.longName?.toLowerCase().contains(query) == true ||
            node.userId?.toLowerCase().contains(query) == true ||
            node.nodeNum.toString().contains(query) ||
            node.nodeNum.toRadixString(16).toLowerCase().contains(query);
      }).toList();
    }

    // Count nodes by filter for badges
    final allNodes = nodes.values.toList();
    final activeCount = allNodes
        .where((n) => _isOnlineNode(presenceMap, n))
        .length;
    final inactiveCount = allNodes
        .where((n) => !_isOnlineNode(presenceMap, n))
        .length;
    final favoritesCount = allNodes.where((n) => n.isFavorite).length;
    final withPositionCount = allNodes
        .where((n) => n.latitude != null && n.longitude != null)
        .length;
    final recentlyDiscoveredCount = allNodes
        .where((n) => n.isRecentlyDiscovered)
        .length;
    final rfCount = allNodes.where((n) => !n.viaMqtt).length;
    final mqttCount = allNodes.where((n) => n.viaMqtt).length;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'nodes_overview',
        stepKeys: const {},
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          leading: const HamburgerMenuButton(),
          centerTitle: true,
          titleWidget: Text(
            context.l10n.nodesScreenTitle(nodes.length),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: context.l10n.nodesScreenScanQrCodeTooltip,
              onPressed: () => Navigator.pushNamed(context, '/qr-scanner'),
            ),
            const DeviceStatusButton(),
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                switch (value) {
                  case 'view_mode':
                    _toggleViewMode();
                  case 'legend':
                    NodesLegendSheet.show(context);
                  case 'settings':
                    Navigator.pushNamed(context, '/settings');
                  case 'help':
                    ref.read(helpProvider.notifier).startTour('nodes_overview');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view_mode',
                  child: Row(
                    children: [
                      Icon(
                        _compactView ? Icons.view_agenda : Icons.view_list,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Text(
                        _compactView
                            ? context.l10n.nodesScreenViewModeCards
                            : context.l10n.nodesScreenViewModeCompact,
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (_compactView)
                  PopupMenuItem(
                    value: 'legend',
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Text(
                          context.l10n.nodesScreenLegendTitle,
                          style: TextStyle(color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Text(
                        context.l10n.nodesScreenHelpMenu,
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
                      const SizedBox(width: AppTheme.spacing12),
                      Text(
                        context.l10n.nodesScreenSettingsMenu,
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          slivers: [
            // Top padding to push content below the glass app bar
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTheme.spacing8),
            ),
            // Pinned search and filter controls
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                hintText: context.l10n.nodesScreenSearchHint,
                textScaler: MediaQuery.textScalerOf(context),
                rebuildKey: Object.hashAll([
                  _activeFilter,
                  _sortOrder,
                  _showSectionHeaders,
                  nodes.length,
                  activeCount,
                  inactiveCount,
                  favoritesCount,
                  withPositionCount,
                  recentlyDiscoveredCount,
                  rfCount,
                  mqttCount,
                ]),
                filterChips: [
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterAll,
                    count: nodes.length,
                    isSelected: _activeFilter == NodeFilter.all,
                    onTap: () => setState(() => _activeFilter = NodeFilter.all),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterActive,
                    count: activeCount,
                    isSelected: _activeFilter == NodeFilter.active,
                    color: AccentColors.green,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.active),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterFavorites,
                    count: favoritesCount,
                    isSelected: _activeFilter == NodeFilter.favorites,
                    color: AppTheme.warningYellow,
                    icon: Icons.star,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.favorites),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterWithPosition,
                    count: withPositionCount,
                    isSelected: _activeFilter == NodeFilter.withPosition,
                    color: AccentColors.cyan,
                    icon: Icons.location_on,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.withPosition),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterInactive,
                    count: inactiveCount,
                    isSelected: _activeFilter == NodeFilter.inactive,
                    color: context.textTertiary,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.inactive),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterNew,
                    count: recentlyDiscoveredCount,
                    isSelected: _activeFilter == NodeFilter.recentlyDiscovered,
                    color: AccentColors.purple,
                    icon: Icons.fiber_new,
                    onTap: () => setState(
                      () => _activeFilter = NodeFilter.recentlyDiscovered,
                    ),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterRf,
                    count: rfCount,
                    isSelected: _activeFilter == NodeFilter.rf,
                    color: AccentColors.emerald,
                    icon: Icons.cell_tower,
                    onTap: () => setState(() => _activeFilter = NodeFilter.rf),
                  ),
                  StatusFilterChip(
                    label: context.l10n.nodesScreenFilterMqtt,
                    count: mqttCount,
                    isSelected: _activeFilter == NodeFilter.mqtt,
                    color: AccentColors.sky,
                    icon: Icons.cloud_outlined,
                    onTap: () =>
                        setState(() => _activeFilter = NodeFilter.mqtt),
                  ),
                  _SortButton(
                    sortOrder: _sortOrder,
                    onChanged: (order) => setState(() => _sortOrder = order),
                  ),
                ],
                trailingControls: [
                  SectionHeadersToggle(
                    enabled: _showSectionHeaders,
                    onToggle: () => setState(
                      () => _showSectionHeaders = !_showSectionHeaders,
                    ),
                  ),
                ],
              ),
            ),
            // Node list content
            //
            // Shimmer is bounded by the discovery cooldown (default
            // 3 min) so a node-db reset that leaves the list empty
            // doesn't render skeletons forever. Outside the cooldown
            // window we fall through to the empty state below.
            if (nodesList.isEmpty &&
                isConnected &&
                isInDiscoveryCooldown &&
                _activeFilter == NodeFilter.all &&
                _searchQuery.isEmpty)
              // Loading shimmer as SliverList (not SliverFillRemaining to avoid intrinsic dimension issues)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Skeletonizer(
                    enabled: true,
                    child: const SkeletonNodeCard(),
                  ),
                  childCount: 8,
                ),
              )
            else if (nodesList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius16,
                          ),
                        ),
                        child: Icon(
                          Icons.group,
                          size: 40,
                          color: context.textTertiary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing24),
                      Text(
                        _activeFilter == NodeFilter.all
                            ? context.l10n.nodesScreenEmptyAll
                            : context.l10n.nodesScreenEmptyFiltered,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      if (_activeFilter != NodeFilter.all) ...[
                        const SizedBox(height: AppTheme.spacing12),
                        TextButton(
                          onPressed: () =>
                              setState(() => _activeFilter = NodeFilter.all),
                          child: Text(context.l10n.nodesScreenShowAllButton),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else ...[
              // Aether Flights Nearby — show matched active flights
              // above the regular node list so they're impossible to miss.
              if (AppFeatureFlags.isAetherEnabled)
                ..._buildAetherFlightSlivers(context),
              ..._buildNodeSlivers(
                context,
                nodesList,
                myNodeNum,
                linkedNodeIds,
                presenceMap,
                isConnected: isConnected,
                isInDiscoveryCooldown: isInDiscoveryCooldown,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build slivers for the "Aether Flights Nearby" section.
  ///
  /// When a mesh node in the local node list matches an active Aether
  /// flight, this section appears at the top of the Nodes screen with
  /// a prominent card linking directly to the flight detail / report page.
  List<Widget> _buildAetherFlightSlivers(BuildContext context) {
    final matches = ref.watch(aetherFlightMatchesProvider);
    if (matches.isEmpty) return [];

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: SectionHeaderDelegate(
          title: context.l10n.nodesScreenSectionAetherFlights,
          count: matches.length,
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return AetherFlightMatchCard(match: matches[index]);
        }, childCount: matches.length),
      ),
    ];
  }

  List<Widget> _buildNodeSlivers(
    BuildContext context,
    List<MeshNode> nodesList,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap, {
    bool isConnected = false,
    bool isInDiscoveryCooldown = false,
  }) {
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

    // Disable section headers when viewing favorites filter since all
    // visible nodes are already favorites — status grouping is misleading.
    final showHeaders =
        _showSectionHeaders && _activeFilter != NodeFilter.favorites;

    if (!showHeaders) {
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
              child: _buildNodeItem(
                node: node,
                isMyNode: isMyNode,
                presenceMap: presenceMap,
                animationsEnabled: animationsEnabled,
              ),
            );
          }, childCount: nodesList.length),
        ),
      ];
    }

    // Build grouped list with sticky section headers
    final sections = _groupNodesIntoSections(
      context,
      nodesList,
      myNodeNum,
      linkedNodeIds,
      presenceMap,
    );
    final nonEmptySections = sections.where((s) => s.nodes.isNotEmpty).toList();

    // Check if we should show loading placeholder:
    // Connected, only have "Your Device" section, no other nodes yet,
    // AND still within the discovery cooldown window (default 3 min),
    // AND at least one node has actually been discovered during this
    // cooldown period. Without the discovered check, a brand-new device
    // with no neighbors would show misleading "Discovering" skeletons
    // on every app restart (cooldown is fresh but nothing is coming).
    final hasOnlyMyDevice =
        nonEmptySections.length == 1 &&
        nonEmptySections.first.title ==
            context.l10n.nodesScreenSectionYourDevice;
    final cooldownState = ref.read(nodeDiscoveryCooldownProvider);
    final hasDiscoveredNodes =
        cooldownState.discoveredDuringCooldown.isNotEmpty;
    final showLoadingPlaceholder =
        isConnected &&
        hasOnlyMyDevice &&
        isInDiscoveryCooldown &&
        hasDiscoveredNodes;

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
              child: _buildNodeItem(
                node: node,
                isMyNode: isMyNode,
                presenceMap: presenceMap,
                animationsEnabled: animationsEnabled,
              ),
            );
          }, childCount: nonEmptySections[sectionIndex].nodes.length),
        ),
      ],
      // Show loading placeholder when waiting for more nodes to be discovered
      if (showLoadingPlaceholder) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: context.l10n.nodesScreenSectionDiscovering,
            count: null, // No count while loading
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                Skeletonizer(enabled: true, child: const SkeletonNodeCard()),
            childCount: 3,
          ),
        ),
      ],
    ];
  }

  List<_NodeSection> _groupNodesIntoSections(
    BuildContext context,
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap,
  ) {
    switch (_sortOrder) {
      case NodeSortOrder.lastHeard:
        return _groupByStatus(
          context,
          nodes,
          myNodeNum,
          linkedNodeIds,
          presenceMap,
        );
      case NodeSortOrder.name:
        return _groupByAlphabet(context, nodes, myNodeNum, linkedNodeIds);
      case NodeSortOrder.signalStrength:
        return _groupBySignal(context, nodes, myNodeNum, linkedNodeIds);
      case NodeSortOrder.batteryLevel:
        return _groupByBattery(context, nodes, myNodeNum, linkedNodeIds);
    }
  }

  List<_NodeSection> _groupByStatus(
    BuildContext context,
    List<MeshNode> nodes,
    int? myNodeNum,
    List<int> linkedNodeIds,
    Map<int, NodePresence> presenceMap,
  ) {
    final myNode = nodes.where((n) => n.nodeNum == myNodeNum).toList();
    // Promote favorited nodes into their own section so they appear right
    // after "Your Device" instead of being buried in status groups.
    final favorites = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              n.isFavorite,
        )
        .toList();
    final favoriteNums = favorites.map((n) => n.nodeNum).toSet();
    final active = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              !favoriteNums.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isActive,
        )
        .toList();
    final fading = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              !favoriteNums.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isFading,
        )
        .toList();
    final inactive = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              !favoriteNums.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isStale,
        )
        .toList();
    final unknown = nodes
        .where(
          (n) =>
              n.nodeNum != myNodeNum &&
              !linkedNodeIds.contains(n.nodeNum) &&
              !favoriteNums.contains(n.nodeNum) &&
              _presenceForNode(presenceMap, n).isUnknown,
        )
        .toList();

    return [
      if (myNode.isNotEmpty)
        _NodeSection(context.l10n.nodesScreenSectionYourDevice, myNode),
      _NodeSection(context.l10n.nodesScreenSectionFavorites, favorites),
      _NodeSection(context.l10n.nodesScreenSectionActive, active),
      _NodeSection(context.l10n.nodesScreenSectionSeenRecently, fading),
      _NodeSection(context.l10n.nodesScreenSectionInactive, inactive),
      _NodeSection(context.l10n.nodesScreenSectionUnknown, unknown),
    ];
  }

  List<_NodeSection> _groupByAlphabet(
    BuildContext context,
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
      if (myNode.isNotEmpty)
        _NodeSection(context.l10n.nodesScreenSectionYourDevice, myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      ...sortedKeys.map((key) => _NodeSection(key, grouped[key]!)),
    ];
  }

  List<_NodeSection> _groupBySignal(
    BuildContext context,
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
      if (myNode.isNotEmpty)
        _NodeSection(context.l10n.nodesScreenSectionYourDevice, myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      _NodeSection(context.l10n.nodesScreenSectionSignalStrong, strong),
      _NodeSection(context.l10n.nodesScreenSectionSignalMedium, medium),
      _NodeSection(context.l10n.nodesScreenSectionSignalWeak, weak),
      _NodeSection(context.l10n.nodesScreenSectionUnknown, unknown),
    ];
  }

  List<_NodeSection> _groupByBattery(
    BuildContext context,
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
      if (myNode.isNotEmpty)
        _NodeSection(context.l10n.nodesScreenSectionYourDevice, myNode),
      // if (linkedNodes.isNotEmpty) _NodeSection('Linked Devices', linkedNodes),
      _NodeSection(context.l10n.nodesScreenSectionCharging, charging),
      _NodeSection(context.l10n.nodesScreenSectionBatteryFull, full),
      _NodeSection(context.l10n.nodesScreenSectionBatteryGood, good),
      _NodeSection(context.l10n.nodesScreenSectionBatteryLow, low),
      _NodeSection(context.l10n.nodesScreenSectionBatteryCritical, critical),
      _NodeSection(context.l10n.nodesScreenSectionUnknown, unknown),
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
        return nodes.where((n) => _isOnlineNode(presenceMap, n)).toList();
      case NodeFilter.inactive:
        return nodes.where((n) => !_isOnlineNode(presenceMap, n)).toList();
      case NodeFilter.favorites:
        return nodes.where((n) => n.isFavorite).toList();
      case NodeFilter.withPosition:
        return nodes
            .where((n) => n.latitude != null && n.longitude != null)
            .toList();
      case NodeFilter.recentlyDiscovered:
        return nodes.where((n) => n.isRecentlyDiscovered).toList();
      case NodeFilter.rf:
        return nodes.where((n) => !n.viaMqtt).toList();
      case NodeFilter.mqtt:
        return nodes.where((n) => n.viaMqtt).toList();
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
                    SizedBox(width: AppTheme.spacing12),
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
                            context.l10n.nodesScreenConnectedDevice,
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
                title: Text(
                  context.l10n.nodesScreenDisconnect,
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
    final connectedDevice = ref.read(connectedDeviceProvider.notifier);
    await transport.disconnect();
    if (!mounted) return;
    connectedDevice.setState(null);
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
  rf,
  mqtt,
}

/// Sort order options for the nodes list
enum NodeSortOrder { lastHeard, name, signalStrength, batteryLevel }

/// Sort button with dropdown
class _SortButton extends StatelessWidget {
  final NodeSortOrder sortOrder;
  final ValueChanged<NodeSortOrder> onChanged;

  const _SortButton({required this.sortOrder, required this.onChanged});

  String _sortLabel(BuildContext context) {
    switch (sortOrder) {
      case NodeSortOrder.lastHeard:
        return context.l10n.nodesScreenSortRecent;
      case NodeSortOrder.name:
        return context.l10n.nodesScreenSortName;
      case NodeSortOrder.signalStrength:
        return context.l10n.nodesScreenSortSignal;
      case NodeSortOrder.batteryLevel:
        return context.l10n.nodesScreenSortBattery;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius20),
      child: Material(
        color: context.card,
        child: InkWell(
          onTap: () => _showSortMenu(context),
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius20),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 14, color: context.textTertiary),
                SizedBox(width: AppTheme.spacing4),
                Text(
                  _sortLabel(context),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(width: AppTheme.spacing2),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      items: [
        _buildMenuItem(
          NodeSortOrder.lastHeard,
          context.l10n.nodesScreenSortMenuMostRecent,
          Icons.schedule,
          context,
        ),
        _buildMenuItem(
          NodeSortOrder.name,
          context.l10n.nodesScreenSortMenuNameAZ,
          Icons.sort_by_alpha,
          context,
        ),
        _buildMenuItem(
          NodeSortOrder.signalStrength,
          context.l10n.nodesScreenSortMenuSignalStrength,
          Icons.signal_cellular_alt,
          context,
        ),
        _buildMenuItem(
          NodeSortOrder.batteryLevel,
          context.l10n.nodesScreenSortMenuBatteryLevel,
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
          const SizedBox(width: AppTheme.spacing12),
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

/// Shows the node detail screen. Can be called from any screen.
///
/// Kept as a thin wrapper for backward compatibility with existing call sites.
void showNodeDetailsSheet(BuildContext context, MeshNode node, bool isMyNode) {
  showNodeDetails(context, node, isMyNode);
}

class _NodeCard extends ConsumerWidget {
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
      AppTheme.graphBlue, // Blue
      const Color(0xFFF59E0B), // Orange
      AppTheme.errorRed, // Red
      AccentColors.emerald, // Green
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

  String _formatDistance(BuildContext context, double? distance) {
    if (distance == null) return '';
    if (distance < 1000) {
      return context.l10n.nodesScreenDistanceMeters(
        distance.toInt().toString(),
      );
    }
    return context.l10n.nodesScreenDistanceKilometers(
      (distance / 1000).toStringAsFixed(1),
    );
  }

  String _formatLastHeard(BuildContext context, DateTime time) {
    final dateFormat = AppTimeFormat.numericDateAndTime(context);
    return dateFormat.format(time);
  }

  Color _blendColor(BuildContext context) {
    if (isMyNode) return context.accentColor;
    if (node.isFavorite) return AppTheme.warningYellow;
    switch (presenceConfidence) {
      case PresenceConfidence.active:
        return AccentColors.green;
      case PresenceConfidence.fading:
        return AccentColors.orange;
      case PresenceConfidence.stale:
        return AccentColors.slate;
      case PresenceConfidence.unknown:
        return AccentColors.purple;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalBars = _calculateSignalBars(node.rssi);
    final statusColor = _presenceColor(context, presenceConfidence);
    final blendColor = _blendColor(context);
    final statusText = presenceStatusText(presenceConfidence, lastHeardAge);
    final cardOpacity = isMyNode || node.isFavorite
        ? 1.0
        : presenceOpacity(presenceConfidence);
    // When this card represents our own device, show the direct link
    // transport (TCP / BLE / USB) instead of the mesh transport (RF /
    // MQTT), because we reach this node via our own phone↔device link,
    // not over the air.
    final myDirectTransport = isMyNode
        ? ref.watch(transportTypeProvider)
        : null;

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: Stack(
              children: [
                // Layer 1: Background blend matching chip/status colour
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          blendColor.withValues(alpha: 0.12),
                          blendColor.withValues(alpha: 0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                ),
                // Layer 2: Border (owner + favorite nodes)
                if (isMyNode)
                  Positioned.fill(
                    child: GradientBorderContainer(
                      borderRadius: 12,
                      borderWidth: 1,
                      accentOpacity: 1.0,
                      defaultBorderColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      child: const SizedBox.expand(),
                    ),
                  )
                else if (node.isFavorite)
                  Positioned.fill(
                    child: GradientBorderContainer(
                      borderRadius: 12,
                      borderWidth: 1,
                      accentOpacity: 1.0,
                      accentColor: AccentColors.yellow,
                      defaultBorderColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                // Layer 3: Bottom-right corner blend into background
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-0.2, -0.2),
                          end: Alignment.bottomRight,
                          colors: [
                            context.background.withValues(alpha: 0),
                            context.background.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Layer 4: Content — fully opaque on top
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: _buildCardContent(
                    context,
                    signalBars,
                    statusColor,
                    statusText,
                    myDirectTransport,
                  ),
                ),
              ],
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
    TransportType? myDirectTransport,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed-width leading column so the avatar + battery ring never
        // shifts the content column. 74 px = 56 avatar + 2×(3 ring + 3 pad + 3 pad).
        SizedBox(
          width: 74,
          child: Center(
            child: NodeAvatar(
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
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(width: AppTheme.spacing12),
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
                  SizedBox(width: AppTheme.spacing8),
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
                    SizedBox(width: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor,
                        borderRadius: BorderRadius.circular(AppTheme.radius6),
                      ),
                      child: Text(
                        context.l10n.nodesScreenYouBadge,
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
              SizedBox(height: AppTheme.spacing6),
              // Status - show "This Device" for your own node
              if (isMyNode)
                Row(
                  children: [
                    Icon(
                      Icons.smartphone,
                      size: 14,
                      color: context.accentColor,
                    ),
                    SizedBox(width: AppTheme.spacing6),
                    Text(
                      context.l10n.nodesScreenThisDevice,
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
                        margin: const EdgeInsets.all(AppTheme.spacing2),
                        decoration: BoxDecoration(
                          color: presenceConfidence.isActive
                              ? statusColor.withValues(alpha: 0.3)
                              : context.textTertiary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing8),
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
              SizedBox(height: AppTheme.spacing4),
              // Last heard
              if (TimestampValidation.isPlausible(node.lastHeard)) ...[
                Row(
                  children: [
                    Icon(Icons.check, size: 14, color: context.accentColor),
                    SizedBox(width: AppTheme.spacing6),
                    Text(
                      _formatLastHeard(context, node.lastHeard!),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing4),
              ],
              // Uptime
              if (node.uptimeSeconds != null) ...[
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: context.textTertiary),
                    SizedBox(width: AppTheme.spacing6),
                    Text(
                      context.l10n.nodesScreenUptimeLabel(
                        formatUptime(node.uptimeSeconds!),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing4),
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
                    SizedBox(width: AppTheme.spacing6),
                    Flexible(
                      child: Text(
                        node.role!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing12),
                  ],
                  Icon(
                    Icons.gps_fixed,
                    size: 14,
                    color: node.hasPosition
                        ? context.accentColor
                        : context.textTertiary,
                  ),
                  SizedBox(width: AppTheme.spacing4),
                  Text(
                    node.hasPosition
                        ? context.l10n.nodesScreenGps
                        : context.l10n.nodesScreenNoGps,
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
                SizedBox(height: AppTheme.spacing4),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 14, color: context.textTertiary),
                    SizedBox(width: AppTheme.spacing6),
                    Text(
                      _formatDistance(context, node.distance),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
              // Logs indicators
              SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  Icon(Icons.article, size: 14, color: context.textTertiary),
                  SizedBox(width: AppTheme.spacing4),
                  Text(
                    context.l10n.nodesScreenLogsLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing8),
                  Icon(Icons.message, size: 14, color: context.textTertiary),
                  SizedBox(width: AppTheme.spacing8),
                  Icon(Icons.place, size: 14, color: context.textTertiary),
                ],
              ),
              // RF metadata row: RSSI, hops, transport
              if (node.rssi != null ||
                  node.hopCount != null ||
                  node.viaMqtt ||
                  myDirectTransport != null) ...[
                SizedBox(height: AppTheme.spacing8),
                Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // RSSI
                    if (node.rssi != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Signal strength bars
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(4, (i) {
                              return Container(
                                margin: const EdgeInsets.only(right: 2),
                                width: 3,
                                height: 8 + (i * 2.5),
                                decoration: BoxDecoration(
                                  color: i < signalBars
                                      ? context.accentColor
                                      : context.textTertiary.withValues(
                                          alpha: 0.3,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius1,
                                  ),
                                ),
                              );
                            }),
                          ),
                          SizedBox(width: AppTheme.spacing4),
                          Text(
                            '${node.rssi} dBm',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    // Hop count
                    if (node.hopCount != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.route,
                            size: 12,
                            color: context.textTertiary,
                          ),
                          SizedBox(width: AppTheme.spacing2),
                          Text(
                            node.hopCount == 0
                                ? context.l10n.nodesScreenHopDirect
                                : context.l10n.nodesScreenHopCount(
                                    node.hopCount!,
                                  ),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    // Transport badge — own node shows direct link
                    // (TCP / BLE / USB); other nodes show mesh path
                    // (MQTT / RF).
                    _TransportBadge(
                      spec: _transportBadgeSpec(
                        context,
                        myDirectTransport,
                        node.viaMqtt,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Status icons & chevron — fixed width so trailing column never
        // shifts the content area.
        SizedBox(
          width: 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (node.isIgnored)
                Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.volume_off,
                    color: AppTheme.errorRed,
                    size: 20,
                  ),
                ),
              if (node.isFavorite)
                const Icon(Icons.star, color: AccentColors.yellow, size: 24)
              else
                const SizedBox(
                  width: AppTheme.spacing24,
                  height: AppTheme.spacing24,
                ),
              const SizedBox(height: AppTheme.spacing8),
              Icon(Icons.chevron_right, color: context.textTertiary, size: 24),
            ],
          ),
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

class _CompactNodeTile extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final PresenceConfidence presenceConfidence;
  final Duration? lastHeardAge;
  final VoidCallback onTap;

  const _CompactNodeTile({
    required this.node,
    required this.isMyNode,
    required this.presenceConfidence,
    required this.lastHeardAge,
    required this.onTap,
  });

  Color _statusColor(BuildContext context) {
    if (isMyNode) return context.accentColor;
    switch (presenceConfidence) {
      case PresenceConfidence.active:
        return AccentColors.green;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final statusText = presenceStatusText(presenceConfidence, lastHeardAge);
    final opacity = isMyNode ? 1.0 : presenceOpacity(presenceConfidence);
    final signalBars = _calculateSignalBars(node.rssi);
    final signalColor = _signalColor(node.rssi);

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: AppTheme.spacing8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Status dot + full name (no truncation)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: presenceConfidence.isActive
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      node.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: context.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing4),
              // Row 2: Metadata with proper spacing
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Wrap(
                  spacing: AppTheme.spacing12,
                  runSpacing: AppTheme.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Signal bars (mini)
                    if (node.rssi != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(4, (i) {
                          final isActive = i < signalBars;
                          return Container(
                            margin: const EdgeInsets.only(right: 1),
                            width: 3,
                            height: 6.0 + (i * 2.0),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? signalColor
                                  : context.textTertiary.withValues(
                                      alpha: 0.25,
                                    ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius1,
                              ),
                            ),
                          );
                        }),
                      ),
                    // Hop count — graphical numbered dots
                    if (node.hopCount != null)
                      _CompactHopIndicator(hopCount: node.hopCount!),
                    // Transport badge (RF / MQTT)
                    Icon(
                      node.viaMqtt ? Icons.cloud_outlined : Icons.cell_tower,
                      size: 14,
                      color: node.viaMqtt
                          ? AccentColors.sky
                          : AccentColors.emerald,
                    ),
                    // Battery
                    if (node.batteryLevel != null && node.batteryLevel! <= 100)
                      Icon(
                        _batteryIcon(node.batteryLevel!),
                        size: 16,
                        color: _batteryColor(node.batteryLevel!),
                      ),
                    // Uptime
                    if (node.uptimeSeconds != null)
                      Text(
                        context.l10n.nodesScreenUptimeLabel(
                          formatUptime(node.uptimeSeconds!),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    // Status text
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateSignalBars(int? rssi) {
    if (rssi == null) return 0;
    if (rssi >= -70) return 4;
    if (rssi >= -80) return 3;
    if (rssi >= -90) return 2;
    if (rssi >= -100) return 1;
    return 0;
  }

  Color _signalColor(int? rssi) {
    if (rssi == null) return AppTheme.errorRed;
    if (rssi >= -70) return AccentColors.green;
    if (rssi >= -85) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  IconData _batteryIcon(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _batteryColor(int level) {
    if (level >= 50) return AccentColors.green;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

/// Graphical hop-count indicator for the compact node tile.
///
/// Renders a row of small numbered circles (1️⃣2️⃣3️⃣…) representing the
/// hop count. A hop count of 0 shows a single filled accent circle labelled
/// "D" (Direct). Caps the visual at 4 dots to keep it compact.
class _CompactHopIndicator extends StatelessWidget {
  final int hopCount;

  const _CompactHopIndicator({required this.hopCount});

  @override
  Widget build(BuildContext context) {
    // Direct neighbour — single accent dot with "D"
    if (hopCount == 0) {
      return _hopDot(
        context,
        label: 'D', // lint-allow: hardcoded-string
        filled: true,
        color: AccentColors.green,
      );
    }

    // Show up to 4 hop dots
    final displayCount = hopCount.clamp(1, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(displayCount, (i) {
        // Colour fades from green (nearby) → yellow → orange → red (far)
        final color = switch (i) {
          0 => AccentColors.green,
          1 => AppTheme.warningYellow,
          2 => AccentColors.orange,
          _ => AppTheme.errorRed,
        };
        return _hopDot(
          context,
          label: '${i + 1}',
          filled: true,
          color: color,
        ); // lint-allow: hardcoded-string
      }),
    );
  }

  Widget _hopDot(
    BuildContext context, {
    required String label,
    required bool filled,
    required Color color,
  }) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color.withValues(alpha: 0.2) : Colors.transparent,
        border: Border.all(color: color, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

/// Spec for a transport badge chip. See [_TransportBadge].
class _TransportBadgeSpec {
  final Color color;
  final IconData icon;
  final String label;
  const _TransportBadgeSpec({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// Chooses the transport badge to show on a node card.
///
/// For the user's own device (`myDirectTransport` non-null), shows the
/// direct link type: TCP over WiFi, BLE, or USB. For any other node,
/// shows the mesh delivery path: MQTT bridge or RF radio.
_TransportBadgeSpec _transportBadgeSpec(
  BuildContext context,
  TransportType? myDirectTransport,
  bool viaMqtt,
) {
  if (myDirectTransport != null) {
    switch (myDirectTransport) {
      case TransportType.network:
        return _TransportBadgeSpec(
          color: AccentColors.cyan,
          icon: Icons.wifi,
          label: context.l10n.nodesScreenTransportTcp,
        );
      case TransportType.ble:
        return _TransportBadgeSpec(
          color: AccentColors.purple,
          icon: Icons.bluetooth,
          label: context.l10n.nodesScreenTransportBle,
        );
      case TransportType.usb:
        return _TransportBadgeSpec(
          color: AccentColors.orange,
          icon: Icons.usb,
          label: context.l10n.nodesScreenTransportUsb,
        );
    }
  }
  if (viaMqtt) {
    return _TransportBadgeSpec(
      color: AccentColors.sky,
      icon: Icons.cloud_outlined,
      label: context.l10n.nodesScreenTransportMqtt,
    );
  }
  return _TransportBadgeSpec(
    color: AccentColors.emerald,
    icon: Icons.cell_tower,
    label: context.l10n.nodesScreenTransportRf,
  );
}

class _TransportBadge extends StatelessWidget {
  final _TransportBadgeSpec spec;
  const _TransportBadge({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 10, color: spec.color),
          SizedBox(width: AppTheme.spacing2),
          Text(
            spec.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: spec.color,
            ),
          ),
        ],
      ),
    );
  }
}
