// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Full-screen NodeDex Constellation graph view.
//
// Mobile-native vertical layout:
//   * GlassScaffold + SearchFilterHeaderDelegate (canonical search + chips)
//   * Hero centre identity card pinned at the top of the list
//   * Related cards (encounter, route, channel, telemetry, message,
//     actions) laid out vertically below, each with a thin spoke in
//     a left gutter so the relationship to the centre still reads.
//
// We tried a 2D radial canvas in earlier iterations; on a 440-px
// portrait viewport with rich (InfoTable-bearing) cards it could not
// avoid overlap, so this slice ships a vertical timeline. The domain
// model + provider stay shape-compatible with a future graph
// renderer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';
import '../../map/map_screen.dart';
import '../../messaging/messaging_screen.dart';
import '../providers/nodedex_providers.dart';
import '../screens/nodedex_detail_screen.dart';
import 'node_constellation_models.dart';
import 'node_constellation_provider.dart';
import 'widgets/node_constellation_actions_tile.dart';
import 'widgets/node_constellation_card.dart';
import 'widgets/node_constellation_hero.dart';
import 'widgets/node_constellation_stat_tile.dart';

class NodeConstellationScreen extends ConsumerStatefulWidget {
  /// Node number that the constellation is centred on. Required.
  final int nodeNum;

  const NodeConstellationScreen({super.key, required this.nodeNum});

  @override
  ConsumerState<NodeConstellationScreen> createState() =>
      _NodeConstellationScreenState();
}

class _NodeConstellationScreenState
    extends ConsumerState<NodeConstellationScreen>
    with LifecycleSafeMixin<NodeConstellationScreen> {
  bool _isTogglingFavourite = false;
  bool _hasLoggedOpen = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _logOpenOnce(NodeDexConstellation constellation) {
    if (_hasLoggedOpen) return;
    _hasLoggedOpen = true;
    AppLogging.nodeDex(
      'Constellation: screen opened for node ${widget.nodeNum} '
      '(centerEntry=${constellation.centerNode != null}, '
      'nodes=${constellation.nodes.length}, '
      'edges=${constellation.edges.length})',
    );
  }

  void _onFilterTimeWindow(NodeDexConstellationTimeWindow window) {
    HapticFeedback.selectionClick();
    AppLogging.nodeDex(
      'Constellation: filter changed time=${window.name} '
      'for node ${widget.nodeNum}',
    );
    ref
        .read(nodeDexConstellationFilterProvider(widget.nodeNum).notifier)
        .setTimeWindow(window);
  }

  void _onToggleRfOnly(bool value) {
    HapticFeedback.selectionClick();
    AppLogging.nodeDex(
      'Constellation: filter changed rfOnly=$value for node ${widget.nodeNum}',
    );
    ref
        .read(nodeDexConstellationFilterProvider(widget.nodeNum).notifier)
        .setRfOnly(value);
  }

  void _onToggleShowInferred(bool value) {
    HapticFeedback.selectionClick();
    AppLogging.nodeDex(
      'Constellation: filter changed showInferred=$value '
      'for node ${widget.nodeNum}',
    );
    ref
        .read(nodeDexConstellationFilterProvider(widget.nodeNum).notifier)
        .setShowInferred(value);
  }

  void _resetFilter() {
    AppLogging.nodeDex(
      'Constellation: filter reset for node ${widget.nodeNum}',
    );
    final notifier = ref.read(
      nodeDexConstellationFilterProvider(widget.nodeNum).notifier,
    );
    notifier.setTimeWindow(NodeDexConstellationTimeWindow.all);
    notifier.setRfOnly(false);
    notifier.setShowInferred(true);
    _searchController.clear();
    safeSetState(() => _searchQuery = '');
  }

  Future<void> _handleNodeTap(NodeDexGraphNode node) async {
    AppLogging.nodeDex(
      'Constellation: card tapped — type=${node.type.name} id=${node.id} '
      'action=${node.action?.name ?? 'none'}',
    );
    final action = node.action;
    if (action == null) return;
    switch (action) {
      case NodeDexGraphAction.message:
        _openMessageThread(node.targetNodeNum ?? widget.nodeNum);
      case NodeDexGraphAction.toggleFavourite:
        await _toggleFavourite(node.targetNodeNum ?? widget.nodeNum);
      case NodeDexGraphAction.viewOnMap:
        _openMap(node.targetNodeNum ?? widget.nodeNum);
      case NodeDexGraphAction.inspectDetails:
        _openDetails(node.targetNodeNum ?? widget.nodeNum);
    }
  }

  void _openMessageThread(int nodeNum) {
    final node = ref.read(nodesProvider)[nodeNum];
    final title =
        node?.displayName ??
        '!${nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0')}';
    final avatarColor = node?.avatarColor;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: nodeNum,
          title: title,
          avatarColor: avatarColor,
        ),
      ),
    );
  }

  void _openMap(int nodeNum) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(initialNodeNum: nodeNum),
      ),
    );
  }

  void _openDetails(int nodeNum) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NodeDexDetailScreen(nodeNum: nodeNum),
      ),
    );
  }

  Future<void> _toggleFavourite(int nodeNum) async {
    if (_isTogglingFavourite) return;
    final MeshNode? node = ref.read(nodesProvider)[nodeNum];
    if (node == null) return;
    safeSetState(() => _isTogglingFavourite = true);
    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    try {
      if (node.isFavorite) {
        await protocol.removeFavoriteNode(nodeNum);
        if (!mounted) return;
        await nodesNotifier.setNodeFavorite(nodeNum, false);
        if (mounted) {
          showSuccessSnackBar(
            context,
            context.l10n.nodeDetailRemovedFromFavorites(node.displayName),
          );
        }
      } else {
        await protocol.setFavoriteNode(nodeNum);
        if (!mounted) return;
        await nodesNotifier.setNodeFavorite(nodeNum, true);
        if (mounted) {
          showSuccessSnackBar(
            context,
            context.l10n.nodeDetailAddedToFavorites(node.displayName),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailFavoriteError(e.toString()),
        );
      }
    } finally {
      safeSetState(() => _isTogglingFavourite = false);
    }
  }

  /// Returns true when [node] either matches [_searchQuery] or is the
  /// centre identity (centre is never hidden by search).
  bool _matchesSearch(NodeDexGraphNode node) {
    if (_searchQuery.isEmpty || node.centered) return true;
    final q = _searchQuery.toLowerCase();
    if (node.label.toLowerCase().contains(q)) return true;
    if (node.subtitle?.toLowerCase().contains(q) ?? false) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final constellation = ref.watch(
      nodeDexNodeConstellationProvider(widget.nodeNum),
    );
    _logOpenOnce(constellation);
    final filter = constellation.filter;
    final l10n = context.l10n;

    final filterChips = <Widget>[
      StatusFilterChip(
        label: l10n.nodedexConstellationFilterTimeNow,
        icon: Icons.bolt_outlined,
        isSelected: filter.timeWindow == NodeDexConstellationTimeWindow.now,
        onTap: () => _onFilterTimeWindow(NodeDexConstellationTimeWindow.now),
      ),
      StatusFilterChip(
        label: l10n.nodedexConstellationFilterTime24h,
        icon: Icons.schedule_outlined,
        isSelected: filter.timeWindow == NodeDexConstellationTimeWindow.last24h,
        onTap: () =>
            _onFilterTimeWindow(NodeDexConstellationTimeWindow.last24h),
      ),
      StatusFilterChip(
        label: l10n.nodedexConstellationFilterTime7d,
        icon: Icons.calendar_view_week_outlined,
        isSelected: filter.timeWindow == NodeDexConstellationTimeWindow.last7d,
        onTap: () => _onFilterTimeWindow(NodeDexConstellationTimeWindow.last7d),
      ),
      StatusFilterChip(
        label: l10n.nodedexConstellationFilterTimeAll,
        icon: Icons.all_inclusive,
        isSelected: filter.timeWindow == NodeDexConstellationTimeWindow.all,
        onTap: () => _onFilterTimeWindow(NodeDexConstellationTimeWindow.all),
      ),
      StatusFilterChip(
        label: l10n.nodedexConstellationFilterRfOnly,
        icon: Icons.cell_tower_outlined,
        isSelected: filter.rfOnly,
        onTap: () => _onToggleRfOnly(!filter.rfOnly),
      ),
      StatusFilterChip(
        label: l10n.nodedexConstellationFilterShowInferred,
        icon: Icons.tips_and_updates_outlined,
        isSelected: filter.showInferred,
        onTap: () => _onToggleShowInferred(!filter.showInferred),
      ),
    ];

    return GlassScaffold(
      title: l10n.nodedexConstellationTitle,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            textScaler: MediaQuery.textScalerOf(context),
            searchController: _searchController,
            searchQuery: _searchQuery,
            hintText: l10n.nodedexSearchHint,
            onSearchChanged: (value) {
              safeSetState(() => _searchQuery = value);
              if (value.isNotEmpty) {
                AppLogging.nodeDex(
                  'Constellation: search query="$value" '
                  'for node ${widget.nodeNum}',
                );
              }
            },
            rebuildKey: Object.hashAll([
              filter,
              _searchQuery,
              constellation.nodes.length,
            ]),
            filterChips: filterChips,
          ),
        ),
        if (constellation.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(constellation),
          )
        else
          ..._buildContentSlivers(constellation),
      ],
    );
  }

  /// Bento-style content: hero photo card, 2-column stat tile grid,
  /// activity cards (route / channel / telemetry), and a single
  /// "My actions" chips tile at the bottom.
  List<Widget> _buildContentSlivers(NodeDexConstellation constellation) {
    final visibleNodes = constellation.nodes.where(_matchesSearch).toList();
    final centre = visibleNodes.where((n) => n.centered).firstOrNull;
    final encounter = visibleNodes
        .where((n) => n.type == NodeDexGraphNodeType.encounter)
        .firstOrNull;
    final message = visibleNodes
        .where((n) => n.type == NodeDexGraphNodeType.message)
        .firstOrNull;
    final activity = visibleNodes.where((n) {
      final t = n.type;
      return t == NodeDexGraphNodeType.routeEvidence ||
          t == NodeDexGraphNodeType.channel ||
          t == NodeDexGraphNodeType.telemetry;
    }).toList();
    final actions = visibleNodes
        .where((n) => n.type == NodeDexGraphNodeType.action)
        .toList();

    final statTiles = _buildStatTiles(centre, encounter, message);

    // Co-seen peers — drives the corner peek of sigils on the hero.
    final coSeenLinks = ref.watch(
      nodeDexHistoricalCoSeenLinksProvider(widget.nodeNum),
    );
    final peerNodeNums = coSeenLinks
        .map((l) => l.otherNodeNum)
        .take(3)
        .toList(growable: false);

    return [
      if (centre != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: NodeConstellationHero(
              node: centre,
              centerNodeNum: widget.nodeNum,
              accent: nodeAccentColor(context, centre),
              hexId: _hexFor(widget.nodeNum),
              lastSeen: _lastSeenString(centre),
              viaMqtt: centre.viaMqtt,
              peerNodeNums: peerNodeNums,
              peerTotal: coSeenLinks.length,
              onTap: _handleNodeTap,
            ),
          ),
        ),
      if (statTiles.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            0,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppTheme.spacing12,
              crossAxisSpacing: AppTheme.spacing12,
              childAspectRatio: 1.35,
            ),
            delegate: SliverChildListDelegate(statTiles),
          ),
        ),
      for (final node in activity)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing12,
            ),
            child: NodeConstellationCard(node: node, onTap: _handleNodeTap),
          ),
        ),
      if (actions.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing4,
              AppTheme.spacing16,
              AppTheme.spacing24,
            ),
            child: NodeConstellationActionsTile(
              actions: actions,
              title: context.l10n.nodedexConstellationTitle,
              labelOf: (ctx, node) => _localizedActionLabel(ctx, node),
              iconOf: _iconForAction,
              accentOf: nodeAccentColor,
              onTap: _handleNodeTap,
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing32)),
    ];
  }

  /// Returns up to four pastel-gradient stat tiles, each driven by
  /// the data already in the constellation. Empty list when there's
  /// nothing meaningful to surface.
  List<Widget> _buildStatTiles(
    NodeDexGraphNode? centre,
    NodeDexGraphNode? encounter,
    NodeDexGraphNode? message,
  ) {
    final tiles = <Widget>[];

    if (encounter != null) {
      final total = _firstDetailValue(encounter, 'Total') ?? '—';
      tiles.add(
        NodeConstellationStatTile(
          value: total,
          label: context.l10n.nodedexConstellationCardEncounters,
          accent: const Color(0xFF7C9CFF),
          icon: Icons.history_toggle_off_outlined,
        ),
      );
    }

    if (centre != null) {
      final lastSeen = _firstDetailValue(centre, 'Last seen');
      if (lastSeen != null) {
        tiles.add(
          NodeConstellationStatTile(
            value: lastSeen,
            label: context.l10n.nodedexLastHeard,
            accent: const Color(0xFFFFD180),
            icon: Icons.access_time_rounded,
          ),
        );
      }
    }

    if (message != null) {
      final total = message.subtitle?.split(' ').first ?? '—';
      tiles.add(
        NodeConstellationStatTile(
          value: total,
          label: context.l10n.nodedexConstellationCardMessages,
          accent: const Color(0xFFB388FF),
          icon: Icons.forum_outlined,
        ),
      );
    }

    return tiles;
  }

  String? _firstDetailValue(NodeDexGraphNode node, String label) {
    for (final d in node.details) {
      if (d.label == label) return d.value;
    }
    return null;
  }

  String? _lastSeenString(NodeDexGraphNode node) {
    return _firstDetailValue(node, 'Last seen');
  }

  String _hexFor(int nodeNum) {
    final hex = nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '!$hex';
  }

  String _localizedActionLabel(BuildContext ctx, NodeDexGraphNode node) {
    final l10n = ctx.l10n;
    switch (node.action) {
      case NodeDexGraphAction.message:
        return l10n.nodedexConstellationActionMessage;
      case NodeDexGraphAction.toggleFavourite:
        return l10n.nodedexConstellationActionFavourite;
      case NodeDexGraphAction.viewOnMap:
        return l10n.nodedexConstellationActionMap;
      case NodeDexGraphAction.inspectDetails:
        return l10n.nodedexConstellationActionDetails;
      case null:
        return node.label;
    }
  }

  IconData _iconForAction(NodeDexGraphAction a) {
    switch (a) {
      case NodeDexGraphAction.message:
        return Icons.forum_outlined;
      case NodeDexGraphAction.toggleFavourite:
        return Icons.star_outline_rounded;
      case NodeDexGraphAction.viewOnMap:
        return Icons.map_outlined;
      case NodeDexGraphAction.inspectDetails:
        return Icons.search_outlined;
    }
  }

  Widget _buildEmptyState(NodeDexConstellation constellation) {
    AppLogging.nodeDex(
      'Constellation: empty graph for node ${widget.nodeNum} — '
      'reason=${constellation.emptyReason?.name ?? 'unknown'}',
    );
    final l10n = context.l10n;
    final body =
        constellation.emptyReason ==
            NodeDexConstellationEmptyReason.missingEntry
        ? l10n.nodedexConstellationEmptyMissing
        : l10n.nodedexConstellationEmptyFiltered;
    final showReset =
        constellation.emptyReason ==
        NodeDexConstellationEmptyReason.filteredOut;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.scatter_plot_outlined,
            Icons.bubble_chart_outlined,
            Icons.hub_outlined,
          ],
          taglines: [body],
          titlePrefix: '',
          titleKeyword: l10n.nodedexConstellationEmptyTitle,
          titleSuffix: '',
          actionLabel: showReset ? l10n.nodedexConstellationEmptyAction : null,
          actionIcon: showReset ? Icons.tune_outlined : null,
          onAction: showReset ? _resetFilter : null,
        ),
      ),
    );
  }
}
