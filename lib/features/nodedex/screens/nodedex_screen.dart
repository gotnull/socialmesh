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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/logging.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_config.dart';
import '../../../models/mesh_models.dart';
import '../../nodes/node_display_name_resolver.dart';
import '../album/album_grid_view.dart' show buildAlbumSlivers;
import '../album/album_providers.dart';
import '../album/card_gallery_screen.dart';
import '../models/nodedex_entry.dart';
import '../models/sigil_evolution.dart';
import '../providers/nodedex_providers.dart';

import '../../settings/settings_screen.dart';
import '../widgets/identity_overlay_painter.dart';
import '../widgets/patina_stamp.dart';
import '../widgets/sigil_painter.dart';
import '../widgets/trait_badge.dart';
import 'nodedex_detail_screen.dart';

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
    final storeAsync = ref.watch(nodeDexStoreProvider);
    final isLoading = storeAsync is AsyncLoading;
    final stats = ref.watch(nodeDexStatsProvider);
    final entries = ref.watch(nodeDexSortedEntriesProvider);
    final currentSort = ref.watch(nodeDexSortProvider);
    final currentFilter = ref.watch(nodeDexFilterProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final viewMode = ref.watch(albumViewModeProvider);
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    // Separate own device from other entries.
    final myEntry = myNodeNum != null
        ? entries.where((e) => e.$1.nodeNum == myNodeNum).toList()
        : <(NodeDexEntry, MeshNode?)>[];
    final otherEntries = entries
        .where((e) => e.$1.nodeNum != myNodeNum)
        .toList();

    AppLogging.nodeDex(
      'Screen build — ${entries.length} entries, '
      'filter: ${currentFilter.name}, sort: ${currentSort.name}, '
      'view: ${viewMode.name}',
    );

    final isAlbumMode = viewMode == AlbumViewMode.album;

    final helpTopicId = isAlbumMode ? 'nodedex_album' : 'nodedex_overview';

    return HelpTourController(
      topicId: helpTopicId,
      stepKeys: const {},
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: GlassScaffold(
          title: 'NodeDex',
          actions: [
            // View mode toggle (list ↔ album).
            _ViewModeToggle(
              isAlbumMode: isAlbumMode,
              onToggle: () {
                final notifier = ref.read(albumViewModeProvider.notifier);
                notifier.toggle();
                AppLogging.nodeDex(
                  'View mode toggled: ${isAlbumMode ? 'album → list' : 'list → album'}',
                );
              },
            ),
            IcoHelpAppBarButton(
              topicId: isAlbumMode ? 'nodedex_album' : 'nodedex_overview',
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
          slivers: isAlbumMode
              ? _buildAlbumSlivers(context, isLoading, reduceMotion)
              : _buildListSlivers(
                  context,
                  isLoading: isLoading,
                  stats: stats,
                  myEntry: myEntry,
                  otherEntries: otherEntries,
                  currentSort: currentSort,
                  currentFilter: currentFilter,
                  reduceMotion: reduceMotion,
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Album view slivers
  // ---------------------------------------------------------------------------

  List<Widget> _buildAlbumSlivers(
    BuildContext context,
    bool isLoading,
    bool reduceMotion,
  ) {
    if (isLoading) {
      return [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Skeletonizer(
              enabled: true,
              effect: AppSkeletonConfig.effect(context),
              child: const SkeletonNodeDexCard(),
            ),
            childCount: 6,
          ),
        ),
      ];
    }

    // buildAlbumSlivers returns slivers directly — no nested scroll view.
    return buildAlbumSlivers(
      context: context,
      ref: ref,
      animate: !reduceMotion,
      onCardTap: (entry, flatIndex) {
        _openDetailFromEntry(entry);
      },
      onCardLongPress: (entry, flatIndex) {
        showCardGallery(
          context: context,
          initialIndex: flatIndex,
          animate: !reduceMotion,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // List view slivers (original layout)
  // ---------------------------------------------------------------------------

  List<Widget> _buildListSlivers(
    BuildContext context, {
    required bool isLoading,
    required NodeDexStats stats,
    required List<(NodeDexEntry, MeshNode?)> myEntry,
    required List<(NodeDexEntry, MeshNode?)> otherEntries,
    required NodeDexSortOrder currentSort,
    required NodeDexFilter currentFilter,
    required bool reduceMotion,
  }) {
    return [
      // Top padding below glass app bar
      const SliverToBoxAdapter(child: SizedBox(height: 8)),

      // Stats summary — not pinned, sizes itself naturally
      if (isLoading)
        SliverToBoxAdapter(
          child: Skeletonizer(
            enabled: true,
            effect: AppSkeletonConfig.effect(context),
            child: const SkeletonNodeDexStatsCard(),
          ),
        )
      else
        SliverToBoxAdapter(child: _NodeDexStatsCard(stats: stats)),

      // Pinned search + filter controls
      SliverPersistentHeader(
        pinned: true,
        delegate: SearchFilterHeaderDelegate(
          textScaler: MediaQuery.textScalerOf(context),
          searchController: _searchController,
          searchQuery: _searchQuery,
          hintText: 'Find a node',
          onSearchChanged: (value) {
            setState(() => _searchQuery = value);
            ref.read(nodeDexSearchProvider.notifier).setQuery(value);
            if (value.isNotEmpty) {
              AppLogging.nodeDex('Search query changed: "$value"');
            }
          },
          rebuildKey: Object.hashAll([
            currentFilter,
            currentSort,
            stats.totalNodes,
            stats.traitDistribution,
            stats.socialTagDistribution,
          ]),
          filterChips: [
            SectionFilterChip(
              label: 'All',
              count: stats.totalNodes,
              isSelected: currentFilter == NodeDexFilter.all,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.all),
            ),
            SectionFilterChip(
              label: 'Tagged',
              count: _taggedCount(stats),
              isSelected: currentFilter == NodeDexFilter.tagged,
              color: AccentColors.yellow,
              icon: Icons.label,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.tagged),
            ),
            _SocialTagFilterChip(
              filter: NodeDexFilter.tagContact,
              tag: NodeSocialTag.contact,
              isSelected: currentFilter == NodeDexFilter.tagContact,
              count: stats.socialTagDistribution[NodeSocialTag.contact] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.tagContact),
            ),
            _SocialTagFilterChip(
              filter: NodeDexFilter.tagTrustedNode,
              tag: NodeSocialTag.trustedNode,
              isSelected: currentFilter == NodeDexFilter.tagTrustedNode,
              count:
                  stats.socialTagDistribution[NodeSocialTag.trustedNode] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.tagTrustedNode),
            ),
            _SocialTagFilterChip(
              filter: NodeDexFilter.tagKnownRelay,
              tag: NodeSocialTag.knownRelay,
              isSelected: currentFilter == NodeDexFilter.tagKnownRelay,
              count: stats.socialTagDistribution[NodeSocialTag.knownRelay] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.tagKnownRelay),
            ),
            _SocialTagFilterChip(
              filter: NodeDexFilter.tagFrequentPeer,
              tag: NodeSocialTag.frequentPeer,
              isSelected: currentFilter == NodeDexFilter.tagFrequentPeer,
              count:
                  stats.socialTagDistribution[NodeSocialTag.frequentPeer] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.tagFrequentPeer),
            ),
            SectionFilterChip(
              label: 'Recent',
              count: 0,
              isSelected: currentFilter == NodeDexFilter.recent,
              color: AccentColors.cyan,
              icon: Icons.schedule,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.recent),
            ),
            _TraitFilterChip(
              filter: NodeDexFilter.wanderers,
              trait: NodeTrait.wanderer,
              isSelected: currentFilter == NodeDexFilter.wanderers,
              count: stats.traitDistribution[NodeTrait.wanderer] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.wanderers),
            ),
            _TraitFilterChip(
              filter: NodeDexFilter.beacons,
              trait: NodeTrait.beacon,
              isSelected: currentFilter == NodeDexFilter.beacons,
              count: stats.traitDistribution[NodeTrait.beacon] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.beacons),
            ),
            _TraitFilterChip(
              filter: NodeDexFilter.ghosts,
              trait: NodeTrait.ghost,
              isSelected: currentFilter == NodeDexFilter.ghosts,
              count: stats.traitDistribution[NodeTrait.ghost] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.ghosts),
            ),
            _TraitFilterChip(
              filter: NodeDexFilter.sentinels,
              trait: NodeTrait.sentinel,
              isSelected: currentFilter == NodeDexFilter.sentinels,
              count: stats.traitDistribution[NodeTrait.sentinel] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.sentinels),
            ),
            _TraitFilterChip(
              filter: NodeDexFilter.relays,
              trait: NodeTrait.relay,
              isSelected: currentFilter == NodeDexFilter.relays,
              count: stats.traitDistribution[NodeTrait.relay] ?? 0,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.relays),
            ),
            _NodeDexSortButton(
              sortOrder: currentSort,
              onChanged: (order) {
                AppLogging.nodeDex(
                  'Sort order changed: ${currentSort.name} → ${order.name}',
                );
                ref.read(nodeDexSortProvider.notifier).setOrder(order);
              },
            ),
          ],
        ),
      ),

      // Your Device section
      if (isLoading) ...[
        // Show skeleton list while loading
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Skeletonizer(
              enabled: true,
              effect: AppSkeletonConfig.effect(context),
              child: const SkeletonNodeDexCard(),
            ),
            childCount: 6,
          ),
        ),
      ] else if (myEntry.isNotEmpty) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(title: 'Your Device'),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final (entry, node) = myEntry[index];
            final tile = _NodeDexListTile(
              entry: entry,
              node: node,
              onTap: () => _openDetail(entry, node),
            );
            if (reduceMotion) return tile;
            return _StaggeredListTile(index: index, child: tile);
          }, childCount: myEntry.length),
        ),
      ],

      // Other nodes list or empty state
      if (!isLoading && otherEntries.isNotEmpty) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: 'Discovered Nodes',
            count: otherEntries.length,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final (entry, node) = otherEntries[index];
            final tile = _NodeDexListTile(
              entry: entry,
              node: node,
              onTap: () => _openDetail(entry, node),
            );
            if (reduceMotion) return tile;
            // Offset by myEntry count so the stagger cascade is continuous.
            return _StaggeredListTile(
              index: myEntry.length + index,
              child: tile,
            );
          }, childCount: otherEntries.length),
        ),
      ] else if (!isLoading && myEntry.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(filter: currentFilter),
        ),

      // Bottom padding for safe area
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

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

  void _openDetailFromEntry(NodeDexEntry entry) {
    AppLogging.nodeDex(
      'Opening detail from album for node ${entry.nodeNum}, '
      'encounters: ${entry.encounterCount}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NodeDexDetailScreen(nodeNum: entry.nodeNum),
      ),
    );
  }
}

// =============================================================================
// View mode toggle button
// =============================================================================

/// Animated toggle button that switches between list and album views.
///
/// Shows a list icon in list mode and a grid/album icon in album mode.
/// The icon cross-fades smoothly on toggle.
class _ViewModeToggle extends StatelessWidget {
  final bool isAlbumMode;
  final VoidCallback onToggle;

  const _ViewModeToggle({required this.isAlbumMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          isAlbumMode
              ? Icons.view_list_rounded
              : Icons.collections_bookmark_outlined,
          key: ValueKey(isAlbumMode),
          size: 22,
        ),
      ),
      tooltip: isAlbumMode ? 'Switch to list view' : 'Switch to album view',
      onPressed: onToggle,
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

            // Compact stats — wrapped in Flexible to prevent overflow
            // on narrow screens / large text scale
            Flexible(
              flex: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactStat(
                    icon: Icons.hexagon_outlined,
                    value: stats.totalNodes.toString(),
                  ),
                  const SizedBox(width: 8),
                  _CompactStat(
                    icon: Icons.public_outlined,
                    value: stats.totalRegions.toString(),
                  ),
                  const SizedBox(width: 8),
                  _CompactStat(
                    icon: Icons.repeat,
                    value: _compactNumber(stats.totalEncounters),
                  ),
                  if (stats.longestDistance != null) ...[
                    const SizedBox(width: 8),
                    _CompactStat(
                      icon: Icons.straighten,
                      value: _formatDistance(stats.longestDistance),
                    ),
                  ],
                ],
              ),
            ),
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
// Filter Helpers
// =============================================================================

/// Computes the total tagged count from stats social tag distribution.
int _taggedCount(NodeDexStats stats) {
  int count = 0;
  for (final entry in stats.socialTagDistribution.values) {
    count += entry;
  }
  return count;
}

// =============================================================================
// Trait Filter Chip (inline in controls header)
// =============================================================================

class _SocialTagFilterChip extends StatelessWidget {
  final NodeDexFilter filter;
  final NodeSocialTag tag;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _SocialTagFilterChip({
    required this.filter,
    required this.tag,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  IconData get _icon {
    return switch (tag) {
      NodeSocialTag.contact => Icons.person_outline,
      NodeSocialTag.trustedNode => Icons.verified_user_outlined,
      NodeSocialTag.knownRelay => Icons.cell_tower,
      NodeSocialTag.frequentPeer => Icons.people_outline,
    };
  }

  Color get _color {
    return switch (tag) {
      NodeSocialTag.contact => const Color(0xFF0EA5E9),
      NodeSocialTag.trustedNode => const Color(0xFF10B981),
      NodeSocialTag.knownRelay => const Color(0xFFF97316),
      NodeSocialTag.frequentPeer => const Color(0xFF8B5CF6),
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

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
            Icon(
              _icon,
              size: 13,
              color: isSelected ? color : context.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              tag.displayLabel,
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
    final disclosure = ref.watch(nodeDexDisclosureProvider(entry.nodeNum));
    final patinaResult = ref.watch(nodeDexPatinaProvider(entry.nodeNum));
    final displayName =
        node?.displayName ??
        entry.lastKnownName ??
        NodeDisplayNameResolver.defaultName(entry.nodeNum);
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    final tileContent = Material(
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
                evolution: SigilEvolution.fromPatina(
                  patinaResult.score,
                  trait: traitResult.primary,
                ),
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

                    // Metadata row: trait + stats + patina indicator
                    Row(
                      children: [
                        // Left side badges — flexible to prevent overflow
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (disclosure.showPrimaryTrait)
                                Flexible(
                                  flex: 0,
                                  child: TraitBadge(
                                    trait: traitResult.primary,
                                    size: TraitBadgeSize.compact,
                                  ),
                                ),
                              if (entry.socialTag != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  flex: 0,
                                  child: SocialTagBadge(
                                    tag: entry.socialTag!,
                                    compact: true,
                                  ),
                                ),
                              ],
                              if (disclosure.showPatinaStamp) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  flex: 0,
                                  child: PatinaIndicator(
                                    result: patinaResult,
                                    accentColor:
                                        entry.sigil?.primaryColor ??
                                        context.accentColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
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

    // Wrap with identity overlay when disclosure tier permits it.
    if (disclosure.showOverlay && disclosure.overlayDensity > 0) {
      return IdentityOverlayTile(
        nodeNum: entry.nodeNum,
        density: disclosure.overlayDensity * 0.5, // Halved for list tiles
        child: tileContent,
      );
    }

    return tileContent;
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
        final displayName =
            node?.displayName ??
            entry.lastKnownName ??
            NodeDisplayNameResolver.defaultName(entry.nodeNum);
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

// =============================================================================
// Staggered list tile entrance animation
// =============================================================================

/// Wraps a list tile with a staggered slide-in + fade entrance animation.
///
/// Each tile slides in from the right with a slight vertical offset and
/// fades in, creating a cascading reveal effect. The stagger delay is
/// capped so large lists don't wait forever.
class _StaggeredListTile extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListTile({required this.index, required this.child});

  @override
  State<_StaggeredListTile> createState() => _StaggeredListTileState();
}

class _StaggeredListTileState extends State<_StaggeredListTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => _hasAnimated;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.08), // subtle rise from below
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger delay: 40ms per tile, capped at 400ms.
    // Use post-frame callback so the delay starts after the first frame
    // renders, preventing Future.delayed from firing on a disposed widget.
    final delay = math.min(widget.index * 40, 400);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (delay == 0) {
        _controller.forward();
        _hasAnimated = true;
        updateKeepAlive();
      } else {
        Future.delayed(Duration(milliseconds: delay), () {
          if (!mounted) return;
          _controller.forward();
          _hasAnimated = true;
          updateKeepAlive();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    // If already animated (e.g. scrolled back into view), show without anim.
    if (_hasAnimated && _controller.isCompleted) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyState extends StatelessWidget {
  final NodeDexFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    // For the main "all" filter, show the full animated empty state
    if (filter == NodeDexFilter.all) {
      return AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.auto_stories_outlined,
            Icons.hexagon_outlined,
            Icons.explore_outlined,
            Icons.cell_tower,
            Icons.hub_outlined,
            Icons.person_search,
          ],
          taglines: const [
            'No nodes discovered yet.\nConnect to a mesh device to start building your field journal.',
            'NodeDex catalogs every node you encounter.\nEach one gets a unique procedural identity.',
            'Discover wanderers, sentinels, and ghosts.\nPersonality traits emerge from behavior patterns.',
            'Tag nodes as contacts or trusted relays.\nBuild your mesh community over time.',
          ],
          titlePrefix: 'Your ',
          titleKeyword: 'NodeDex',
          titleSuffix: ' is empty',
        ),
      );
    }

    // For filtered views, show a simpler contextual empty state
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
      NodeDexFilter.tagContact => (
        Icons.person_outline,
        'No contacts',
        'Nodes you classify as Contact will appear here. Long-press a node to assign this tag.',
      ),
      NodeDexFilter.tagTrustedNode => (
        Icons.verified_user_outlined,
        'No trusted nodes',
        'Nodes you classify as Trusted Node will appear here. Long-press a node to assign this tag.',
      ),
      NodeDexFilter.tagKnownRelay => (
        Icons.cell_tower,
        'No known relays',
        'Nodes you classify as Known Relay will appear here. Long-press a node to assign this tag.',
      ),
      NodeDexFilter.tagFrequentPeer => (
        Icons.people_outline,
        'No frequent peers',
        'Nodes you classify as Frequent Peer will appear here. Long-press a node to assign this tag.',
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
