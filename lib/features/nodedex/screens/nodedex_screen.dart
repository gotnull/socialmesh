// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Main Screen — the mesh field journal.
//
// Displays all discovered nodes with their procedural sigils,
// inferred traits, encounter statistics, and social tags.
//
// Layout:
// - Glass app bar with title and constellation action
// - Pinned stats summary header (total nodes, regions, explorer title)
// - Pinned search bar + filter chips + sort control (matching Nodes screen)
// - Scrollable node list with sigil avatars and metadata
//
// This screen is purely additive — it reads from nodeDexProvider
// and nodesProvider without modifying any existing functionality.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/mesh_models.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../../settings/settings_screen.dart';
import '../widgets/sigil_painter.dart';
import '../widgets/trait_badge.dart';
import 'nodedex_detail_screen.dart';
import 'nodedex_constellation_screen.dart';

/// The main NodeDex screen — a personal mesh field journal.
///
/// Shows all discovered nodes enriched with procedural identity,
/// inferred personality traits, and encounter history. Accessible
/// from the main shell drawer menu.
class NodeDexScreen extends ConsumerStatefulWidget {
  const NodeDexScreen({super.key});

  @override
  ConsumerState<NodeDexScreen> createState() => _NodeDexScreenState();
}

class _NodeDexScreenState extends ConsumerState<NodeDexScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    final stats = ref.watch(nodeDexStatsProvider);
    final entries = ref.watch(nodeDexSortedEntriesProvider);
    final currentSort = ref.watch(nodeDexSortProvider);
    final currentFilter = ref.watch(nodeDexFilterProvider);

    AppLogging.nodeDex(
      'Screen build — ${entries.length} entries, '
      'filter: ${currentFilter.name}, sort: ${currentSort.name}',
    );

    return HelpTourController(
      topicId: 'nodedex_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: GlassScaffold(
          title: 'NodeDex',
          actions: [
            IcoHelpAppBarButton(topicId: 'nodedex_overview'),
            // Constellation view button
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 22),
              tooltip: 'Mesh Constellation',
              onPressed: _openConstellation,
            ),
            // Settings link
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
          slivers: [
            // Top padding below glass app bar
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Stats summary — not pinned, sizes itself naturally
            SliverToBoxAdapter(child: _NodeDexStatsCard(stats: stats)),

            // Pinned search + filter controls
            SliverPersistentHeader(
              pinned: true,
              delegate: _NodeDexControlsHeaderDelegate(
                textScaler: MediaQuery.textScalerOf(context),
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                  ref.read(nodeDexSearchProvider.notifier).setQuery(value);
                  if (value.isNotEmpty) {
                    AppLogging.nodeDex('Search query changed: "$value"');
                  }
                },
                currentFilter: currentFilter,
                onFilterChanged: (filter) {
                  AppLogging.nodeDex(
                    'Filter changed: ${currentFilter.name} → ${filter.name}',
                  );
                  ref.read(nodeDexFilterProvider.notifier).setFilter(filter);
                },
                currentSort: currentSort,
                onSortChanged: (order) {
                  AppLogging.nodeDex(
                    'Sort order changed: ${currentSort.name} → ${order.name}',
                  );
                  ref.read(nodeDexSortProvider.notifier).setOrder(order);
                },
                stats: stats,
              ),
            ),

            // Node list or empty state
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(filter: currentFilter),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final (entry, node) = entries[index];
                  return _NodeDexListTile(
                    entry: entry,
                    node: node,
                    onTap: () => _openDetail(entry, node),
                  );
                }, childCount: entries.length),
              ),

            // Bottom padding for safe area
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(NodeDexEntry entry, MeshNode? node) {
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    AppLogging.nodeDex(
      'Opening detail for node ${entry.nodeNum} ($hexId), '
      'name: ${node?.displayName ?? 'unknown'}, '
      'encounters: ${entry.encounterCount}, '
      'trait: ${entry.socialTag?.name ?? 'untagged'}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NodeDexDetailScreen(nodeNum: entry.nodeNum),
      ),
    );
  }

  void _openConstellation() {
    AppLogging.nodeDex('Opening constellation view');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NodeDexConstellationScreen(),
      ),
    );
  }
}

// =============================================================================
// Pinned Stats Header Delegate
// =============================================================================

class _NodeDexStatsCard extends StatelessWidget {
  final NodeDexStats stats;

  const _NodeDexStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final title = stats.explorerTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.accentColor.withValues(alpha: 0.08),
              context.accentColor.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.accentColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Explorer title
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title.displayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.accentColor,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Compact stats
            _CompactStat(
              icon: Icons.hexagon_outlined,
              value: stats.totalNodes.toString(),
            ),
            const SizedBox(width: 12),
            _CompactStat(
              icon: Icons.public_outlined,
              value: stats.totalRegions.toString(),
            ),
            const SizedBox(width: 12),
            _CompactStat(
              icon: Icons.repeat,
              value: _compactNumber(stats.totalEncounters),
            ),
            if (stats.longestDistance != null) ...[
              const SizedBox(width: 12),
              _CompactStat(
                icon: Icons.straighten,
                value: _formatDistance(stats.longestDistance),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _compactNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CompactStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.textTertiary),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Pinned Search + Filter Controls Delegate
// =============================================================================

class _NodeDexControlsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final NodeDexFilter currentFilter;
  final ValueChanged<NodeDexFilter> onFilterChanged;
  final NodeDexSortOrder currentSort;
  final ValueChanged<NodeDexSortOrder> onSortChanged;
  final NodeDexStats stats;
  final TextScaler textScaler;

  _NodeDexControlsHeaderDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.currentSort,
    required this.onSortChanged,
    required this.stats,
    required this.textScaler,
  });

  // The search field height is constrained explicitly via
  // InputDecoration.constraints in build(), so the extent is deterministic.
  // Layout: outerPad (6+6) + searchField + chipsRow (44) + divider (1).
  double get _searchFieldHeight =>
      math.max(kMinInteractiveDimension, textScaler.scale(48));

  double get _computedExtent => 12 + _searchFieldHeight + 44 + 8 + 1;

  @override
  double get minExtent => _computedExtent;

  @override
  double get maxExtent => _computedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: context.background.withValues(alpha: 0.8),
          child: Column(
            children: [
              // Search bar — height constrained to match _computedExtent
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: SizedBox(
                  height: _searchFieldHeight,
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
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.textTertiary,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: context.textTertiary,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        isDense: true,
                        constraints: BoxConstraints.tightFor(
                          height: _searchFieldHeight,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter chips row with sort button
              SizedBox(
                height: 44,
                child: Row(
                  children: [
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
                              count: stats.totalNodes,
                              isSelected: currentFilter == NodeDexFilter.all,
                              onTap: () => onFilterChanged(NodeDexFilter.all),
                            ),
                            const SizedBox(width: 12),
                            SectionFilterChip(
                              label: 'Tagged',
                              count: _taggedCount(),
                              isSelected: currentFilter == NodeDexFilter.tagged,
                              color: AccentColors.yellow,
                              icon: Icons.label,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.tagged),
                            ),
                            const SizedBox(width: 12),
                            SectionFilterChip(
                              label: 'Recent',
                              count: 0,
                              isSelected: currentFilter == NodeDexFilter.recent,
                              color: AccentColors.cyan,
                              icon: Icons.schedule,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.recent),
                            ),
                            const SizedBox(width: 12),
                            _TraitFilterChip(
                              filter: NodeDexFilter.wanderers,
                              trait: NodeTrait.wanderer,
                              isSelected:
                                  currentFilter == NodeDexFilter.wanderers,
                              count:
                                  stats.traitDistribution[NodeTrait.wanderer] ??
                                  0,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.wanderers),
                            ),
                            const SizedBox(width: 12),
                            _TraitFilterChip(
                              filter: NodeDexFilter.beacons,
                              trait: NodeTrait.beacon,
                              isSelected:
                                  currentFilter == NodeDexFilter.beacons,
                              count:
                                  stats.traitDistribution[NodeTrait.beacon] ??
                                  0,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.beacons),
                            ),
                            const SizedBox(width: 12),
                            _TraitFilterChip(
                              filter: NodeDexFilter.ghosts,
                              trait: NodeTrait.ghost,
                              isSelected: currentFilter == NodeDexFilter.ghosts,
                              count:
                                  stats.traitDistribution[NodeTrait.ghost] ?? 0,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.ghosts),
                            ),
                            const SizedBox(width: 12),
                            _TraitFilterChip(
                              filter: NodeDexFilter.sentinels,
                              trait: NodeTrait.sentinel,
                              isSelected:
                                  currentFilter == NodeDexFilter.sentinels,
                              count:
                                  stats.traitDistribution[NodeTrait.sentinel] ??
                                  0,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.sentinels),
                            ),
                            const SizedBox(width: 12),
                            _TraitFilterChip(
                              filter: NodeDexFilter.relays,
                              trait: NodeTrait.relay,
                              isSelected: currentFilter == NodeDexFilter.relays,
                              count:
                                  stats.traitDistribution[NodeTrait.relay] ?? 0,
                              onTap: () =>
                                  onFilterChanged(NodeDexFilter.relays),
                            ),
                            const SizedBox(width: 12),
                            _NodeDexSortButton(
                              sortOrder: currentSort,
                              onChanged: onSortChanged,
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Divider
              Container(
                height: 1,
                color: context.border.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _taggedCount() {
    int count = 0;
    for (final entry in stats.socialTagDistribution.values) {
      count += entry;
    }
    return count;
  }

  @override
  bool shouldRebuild(covariant _NodeDexControlsHeaderDelegate oldDelegate) {
    return searchQuery != oldDelegate.searchQuery ||
        currentFilter != oldDelegate.currentFilter ||
        currentSort != oldDelegate.currentSort ||
        stats.totalNodes != oldDelegate.stats.totalNodes ||
        stats.traitDistribution != oldDelegate.stats.traitDistribution ||
        stats.socialTagDistribution != oldDelegate.stats.socialTagDistribution;
  }
}

// =============================================================================
// Trait Filter Chip (inline in controls header)
// =============================================================================

class _TraitFilterChip extends StatelessWidget {
  final NodeDexFilter filter;
  final NodeTrait trait;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _TraitFilterChip({
    required this.filter,
    required this.trait,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = trait.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : context.border.withValues(alpha: 0.3),
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TraitIcon(trait: trait, size: 13),
            const SizedBox(width: 4),
            Text(
              trait.displayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : context.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.25)
                      : context.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : context.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sort Button (inline in filter chip row)
// =============================================================================

class _NodeDexSortButton extends StatelessWidget {
  final NodeDexSortOrder sortOrder;
  final ValueChanged<NodeDexSortOrder> onChanged;

  const _NodeDexSortButton({required this.sortOrder, required this.onChanged});

  String get _sortLabel {
    return switch (sortOrder) {
      NodeDexSortOrder.lastSeen => 'Last Seen',
      NodeDexSortOrder.firstSeen => 'Discovered',
      NodeDexSortOrder.encounters => 'Encounters',
      NodeDexSortOrder.distance => 'Range',
      NodeDexSortOrder.name => 'Name',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSortMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 14, color: context.textSecondary),
            const SizedBox(width: 4),
            Text(
              _sortLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<NodeDexSortOrder>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: [
        _buildMenuItem(
          context,
          NodeDexSortOrder.lastSeen,
          'Last Seen',
          Icons.schedule,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.firstSeen,
          'First Discovered',
          Icons.calendar_today_outlined,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.encounters,
          'Most Encounters',
          Icons.repeat,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.distance,
          'Longest Range',
          Icons.straighten,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.name,
          'Name',
          Icons.sort_by_alpha,
        ),
      ],
    ).then((value) {
      if (value != null) {
        onChanged(value);
      }
    });
  }

  PopupMenuItem<NodeDexSortOrder> _buildMenuItem(
    BuildContext context,
    NodeDexSortOrder order,
    String label,
    IconData icon,
  ) {
    final isSelected = order == sortOrder;
    return PopupMenuItem(
      value: order,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? context.accentColor : context.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? context.accentColor : context.textPrimary,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(Icons.check, size: 16, color: context.accentColor),
        ],
      ),
    );
  }
}

// =============================================================================
// List Tile
// =============================================================================

/// A single row in the NodeDex list showing a node's sigil, name,
/// trait, encounter stats, and social tag.
class _NodeDexListTile extends ConsumerWidget {
  final NodeDexEntry entry;
  final MeshNode? node;
  final VoidCallback onTap;

  const _NodeDexListTile({
    required this.entry,
    required this.node,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traitResult = ref.watch(nodeDexTraitProvider(entry.nodeNum));
    final displayName = node?.displayName ?? 'Node ${entry.nodeNum}';
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showQuickActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Sigil avatar
              SigilAvatar(
                sigil: entry.sigil,
                nodeNum: entry.nodeNum,
                size: 48,
                badge: _onlineBadge(context),
              ),
              const SizedBox(width: 14),

              // Name, ID, and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hexId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.textTertiary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Metadata row: trait + stats
                    Row(
                      children: [
                        TraitBadge(
                          trait: traitResult.primary,
                          size: TraitBadgeSize.compact,
                        ),
                        if (entry.socialTag != null) ...[
                          const SizedBox(width: 6),
                          SocialTagBadge(tag: entry.socialTag!, compact: true),
                        ],
                        const Spacer(),
                        // Encounter count
                        _MetricChip(
                          icon: Icons.repeat,
                          value: entry.encounterCount.toString(),
                          tooltip: '${entry.encounterCount} encounters',
                        ),
                        if (entry.maxDistanceSeen != null) ...[
                          const SizedBox(width: 6),
                          _MetricChip(
                            icon: Icons.straighten,
                            value: _shortDistance(entry.maxDistanceSeen!),
                            tooltip:
                                'Max range: ${_shortDistance(entry.maxDistanceSeen!)}',
                          ),
                        ],
                      ],
                    ),

                    // User note preview
                    if (entry.userNote != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.userNote!,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.textTertiary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build an online indicator badge if the node is currently active.
  Widget? _onlineBadge(BuildContext context) {
    if (node == null) return null;
    final lastHeard = node!.lastHeard;
    if (lastHeard == null) return null;

    final age = DateTime.now().difference(lastHeard);
    if (age.inMinutes > 30) return null;

    // Online: seen within last 30 minutes
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AccentColors.green,
        shape: BoxShape.circle,
        border: Border.all(color: context.background, width: 2),
        boxShadow: [
          BoxShadow(
            color: AccentColors.green.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  String _shortDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }

  void _showQuickActions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final displayName = node?.displayName ?? 'Node ${entry.nodeNum}';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Quick tag actions
                ...NodeSocialTag.values.map((tag) {
                  final isActive = entry.socialTag == tag;
                  return ListTile(
                    leading: Icon(
                      _tagIcon(tag),
                      color: isActive
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                    title: Text(
                      tag.displayLabel,
                      style: TextStyle(
                        color: isActive
                            ? context.accentColor
                            : context.textPrimary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isActive
                        ? Icon(
                            Icons.check_circle,
                            size: 20,
                            color: context.accentColor,
                          )
                        : null,
                    onTap: () {
                      if (isActive) {
                        ref
                            .read(nodeDexProvider.notifier)
                            .setSocialTag(entry.nodeNum, null);
                      } else {
                        ref
                            .read(nodeDexProvider.notifier)
                            .setSocialTag(entry.nodeNum, tag);
                      }
                      Navigator.pop(sheetContext);
                    },
                  );
                }),
                if (entry.socialTag != null) ...[
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.clear, color: context.textTertiary),
                    title: Text(
                      'Remove Tag',
                      style: TextStyle(color: context.textSecondary),
                    ),
                    onTap: () {
                      ref
                          .read(nodeDexProvider.notifier)
                          .setSocialTag(entry.nodeNum, null);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _tagIcon(NodeSocialTag tag) {
    return switch (tag) {
      NodeSocialTag.contact => Icons.person_outline,
      NodeSocialTag.trustedNode => Icons.verified_user_outlined,
      NodeSocialTag.knownRelay => Icons.cell_tower,
      NodeSocialTag.frequentPeer => Icons.people_outline,
    };
  }
}

/// Compact metric chip showing an icon and value.
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String tooltip;

  const _MetricChip({
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: context.textTertiary),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  final NodeDexFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      NodeDexFilter.all => (
        Icons.hexagon_outlined,
        'No nodes discovered yet',
        'Connect to a Meshtastic device and nodes will appear here as they are discovered on the mesh.',
      ),
      NodeDexFilter.tagged => (
        Icons.label_outline,
        'No tagged nodes',
        'Long-press a node in the list to assign a social tag like Contact, Trusted Node, or Known Relay.',
      ),
      NodeDexFilter.recent => (
        Icons.schedule,
        'No recent discoveries',
        'Nodes discovered in the last 24 hours will appear here.',
      ),
      NodeDexFilter.wanderers => (
        Icons.explore_outlined,
        'No wanderers found',
        'Wanderers are nodes seen across multiple locations. They emerge over time as position data accumulates.',
      ),
      NodeDexFilter.beacons => (
        Icons.flare_outlined,
        'No beacons found',
        'Beacons are nodes with very high activity and frequent encounters. They take time to classify.',
      ),
      NodeDexFilter.ghosts => (
        Icons.visibility_off_outlined,
        'No ghosts found',
        'Ghosts are nodes that appear rarely relative to how long they have been known.',
      ),
      NodeDexFilter.sentinels => (
        Icons.shield_outlined,
        'No sentinels found',
        'Sentinels are long-lived, fixed-position nodes with reliable presence.',
      ),
      NodeDexFilter.relays => (
        Icons.swap_horiz,
        'No relays found',
        'Relays are nodes with router roles and active traffic forwarding.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: context.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: context.textTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
