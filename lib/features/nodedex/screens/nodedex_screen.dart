// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../pet/widgets/pet_mini_preview.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../core/units/distance_format.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/help_providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/metric_chip.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/staggered_list_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../core/widgets/skeleton_config.dart';
import '../../../models/mesh_models.dart';
import '../../nodes/node_display_name_resolver.dart';
import '../album/album_grid_view.dart' show buildAlbumSlivers;
import '../album/album_providers.dart';
import '../album/card_gallery_screen.dart';
import '../models/nodedex_entry.dart';
import '../models/observed_radio_preset.dart';
import '../models/sigil_evolution.dart';
import '../providers/nodedex_providers.dart';
import '../services/trust_score.dart';

import '../../settings/settings_screen.dart';
import '../map/nodedex_map_screen.dart';
import '../widgets/identity_overlay_painter.dart';
import '../widgets/patina_stamp.dart';
import '../widgets/sigil_painter.dart';
import '../widgets/reticulum_activity_badge.dart';
import '../widgets/trait_badge.dart';
import '../widgets/trust_indicator.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(nodeDexSearchProvider);
  }

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
    final radioPresetFilter = ref.watch(nodeDexRadioPresetFilterProvider);
    final observedPresets = ref.watch(nodeDexObservedPresetsProvider);
    final searchQuery = ref.watch(nodeDexSearchProvider);
    final viewMode = ref.watch(albumViewModeProvider);
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);
    final galleryEntryCount = ref.watch(albumCardCountProvider);

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
          resizeToAvoidBottomInset: false,
          title: context.l10n.nodedexTitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.view_carousel_outlined),
              tooltip: context.l10n.nodedexCardGalleryTooltip,
              onPressed: galleryEntryCount == 0
                  ? null
                  : () {
                      AppLogging.nodeDex(
                        'Card gallery opened from app bar: '
                        '$galleryEntryCount cards',
                      );
                      showCardGallery(
                        context: context,
                        initialIndex: 0,
                        animate: !reduceMotion,
                      );
                    },
            ),
            // Primary IconButton: view mode toggle (list ↔ album).
            // Per CLAUDE.md, the rest goes into AppBarOverflowMenu.
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
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                switch (value) {
                  case 'map':
                    openNodeDexMap(context);
                  case 'help':
                    ref
                        .read(helpProvider.notifier)
                        .startTour(
                          isAlbumMode ? 'nodedex_album' : 'nodedex_overview',
                        );
                  case 'settings':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'map',
                  child: ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(context.l10n.nodedexMapTooltip),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(context.l10n.nodedexMenuHelp),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.l10n.nodedexSettingsTooltip),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
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
                  radioPresetFilter: radioPresetFilter,
                  observedPresets: observedPresets,
                  reduceMotion: reduceMotion,
                  searchQuery: searchQuery,
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
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),
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
    required Set<int> radioPresetFilter,
    required Set<int> observedPresets,
    required bool reduceMotion,
    required String searchQuery,
  }) {
    return [
      // Top padding below glass app bar
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),

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
        SliverToBoxAdapter(
          child: _NodeDexStatsCard(
            stats: stats,
            units: ref.watch(measurementUnitsProvider),
          ),
        ),

      // Pinned search + filter controls
      SliverPersistentHeader(
        pinned: true,
        delegate: SearchFilterHeaderDelegate(
          textScaler: MediaQuery.textScalerOf(context),
          searchController: _searchController,
          searchQuery: searchQuery,
          hintText: context.l10n.nodedexSearchHint,
          onSearchChanged: (value) {
            ref.read(nodeDexSearchProvider.notifier).setQuery(value);
            if (value.isNotEmpty) {
              AppLogging.nodeDex('Search query changed: "$value"');
            }
          },
          rebuildKey: Object.hashAll([
            currentFilter,
            currentSort,
            radioPresetFilter,
            stats.totalNodes,
            stats.traitDistribution,
            stats.socialTagDistribution,
          ]),
          filterChips: [
            StatusFilterChip(
              label: context.l10n.nodedexFilterAll,
              count: stats.totalNodes,
              isSelected: currentFilter == NodeDexFilter.all,
              onTap: () => ref
                  .read(nodeDexFilterProvider.notifier)
                  .setFilter(NodeDexFilter.all),
            ),
            StatusFilterChip(
              label: context.l10n.nodedexFilterTagged,
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
            StatusFilterChip(
              label: context.l10n.nodedexFilterRecent,
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
            if (observedPresets.isNotEmpty)
              _RadioPresetFilterChip(
                activePresets: radioPresetFilter,
                availablePresets: observedPresets,
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
          delegate: SectionHeaderDelegate(
            title: context.l10n.nodedexSectionYourDevice,
          ),
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
            return StaggeredListTile(index: index, child: tile);
          }, childCount: myEntry.length),
        ),
      ],

      // Other nodes list or empty state
      if (!isLoading && otherEntries.isNotEmpty) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: context.l10n.nodedexSectionDiscoveredNodes,
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
            return StaggeredListTile(
              index: myEntry.length + index,
              child: tile,
            );
          }, childCount: otherEntries.length),
        ),
      ] else if (AppLogging.forceEmptyStates || (!isLoading && myEntry.isEmpty))
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
      tooltip: isAlbumMode
          ? context.l10n.nodedexSwitchToListView
          : context.l10n.nodedexSwitchToAlbumView,
      onPressed: onToggle,
    );
  }
}

// =============================================================================
// Pinned Stats Header Delegate
// =============================================================================

class _NodeDexStatsCard extends StatelessWidget {
  final NodeDexStats stats;
  final MeasurementUnits units;

  const _NodeDexStatsCard({required this.stats, required this.units});

  @override
  Widget build(BuildContext context) {
    final title = stats.explorerTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 4, 16, 4),
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
          borderRadius: BorderRadius.circular(AppTheme.radius14),
          border: Border.all(
            color: context.accentColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Explorer title — centered
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: context.accentColor),
                const SizedBox(width: AppTheme.spacing6),
                Flexible(
                  child: Text(
                    title.displayLabel(context.l10n),
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

            const SizedBox(height: AppTheme.spacing8),

            // Stats chips — full width, evenly spaced
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.hexagon_outlined,
                    value: stats.totalNodes.toString(),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: _StatChip(
                    icon: Icons.public_outlined,
                    value: stats.totalRegions.toString(),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: _StatChip(
                    icon: Icons.repeat,
                    value: _compactNumber(stats.totalEncounters),
                  ),
                ),
                if (stats.longestDistance != null) ...[
                  const SizedBox(width: AppTheme.spacing6),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.straighten,
                      value: _formatDistance(context, stats.longestDistance),
                    ),
                  ),
                ],
              ],
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

  String _formatDistance(BuildContext context, double? meters) {
    if (meters == null) return '--';
    return formatDistanceMeters(meters, units, context.l10n);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: context.border.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing3),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
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
      NodeSocialTag.contact => AccentColors.sky,
      NodeSocialTag.trustedNode => AccentColors.emerald,
      NodeSocialTag.knownRelay => AccentColors.orange,
      NodeSocialTag.frequentPeer => AppTheme.primaryPurple,
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
          borderRadius: BorderRadius.circular(AppTheme.radius20),
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
            const SizedBox(width: AppTheme.spacing4),
            Text(
              tag.displayLabel(context.l10n),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : context.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: AppTheme.spacing5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.25)
                      : context.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
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
          borderRadius: BorderRadius.circular(AppTheme.radius20),
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
            const SizedBox(width: AppTheme.spacing4),
            Text(
              trait.displayLabel(context.l10n),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : context.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: AppTheme.spacing5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.25)
                      : context.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
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

  String _localizedSortLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (sortOrder) {
      NodeDexSortOrder.lastSeen => l10n.nodedexSortLastSeen,
      NodeDexSortOrder.firstSeen => l10n.nodedexSortDiscovered,
      NodeDexSortOrder.encounters => l10n.nodedexSortEncounters,
      NodeDexSortOrder.distance => l10n.nodedexSortRange,
      NodeDexSortOrder.name => l10n.nodedexSortName,
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
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(
            color: context.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 14, color: context.textSecondary),
            const SizedBox(width: AppTheme.spacing4),
            Text(
              _localizedSortLabel(context),
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
          context.l10n.nodedexSortLastSeen,
          Icons.schedule,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.firstSeen,
          context.l10n.nodedexSortFirstDiscovered,
          Icons.calendar_today_outlined,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.encounters,
          context.l10n.nodedexSortMostEncounters,
          Icons.repeat,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.distance,
          context.l10n.nodedexSortLongestRange,
          Icons.straighten,
        ),
        _buildMenuItem(
          context,
          NodeDexSortOrder.name,
          context.l10n.nodedexSortName,
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
          const SizedBox(width: AppTheme.spacing10),
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
    final trustResult = ref.watch(nodeDexTrustProvider(entry.nodeNum));
    final displayName =
        entry.localNickname ??
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: AppTheme.spacing14),

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
                        const SizedBox(width: AppTheme.spacing6),
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
                    const SizedBox(height: AppTheme.spacing4),

                    // Metadata chips — single Wrap for natural flow
                    Wrap(
                      spacing: AppTheme.spacing4,
                      runSpacing: AppTheme.spacing4,
                      children: [
                        if (AppFeatureFlags.isReticulumTunnelEnabled)
                          ReticulumActivityBadge(nodeNum: entry.nodeNum),
                        if (disclosure.showPrimaryTrait)
                          TraitBadge(
                            trait: traitResult.primary,
                            size: TraitBadgeSize.compact,
                          ),
                        if (entry.socialTag != null)
                          SocialTagBadge(tag: entry.socialTag!, compact: true),
                        if (disclosure.showPatinaStamp)
                          PatinaIndicator(
                            result: patinaResult,
                            accentColor:
                                entry.sigil?.primaryColor ??
                                context.accentColor,
                          ),
                        if (disclosure.showPrimaryTrait &&
                            trustResult.level != TrustLevel.unknown)
                          TrustIndicator(
                            level: trustResult.level,
                            size: TrustIndicatorSize.compact,
                          ),
                        // Encounter count
                        MetricChip(
                          icon: Icons.repeat,
                          value: entry.encounterCount.toString(),
                          tooltip: context.l10n.nodedexEncountersCount(
                            entry.encounterCount,
                          ),
                        ),
                        if (entry.maxDistanceSeen != null)
                          MetricChip(
                            icon: Icons.straighten,
                            value: _shortDistance(entry.maxDistanceSeen!),
                            tooltip: context.l10n.nodedexMaxRange(
                              _shortDistance(entry.maxDistanceSeen!),
                            ),
                          ),
                        if (entry.lastObservedOnPreset != null)
                          _RadioPresetChip(
                            presetValue: entry.lastObservedOnPreset!,
                          ),
                      ],
                    ),

                    // Discovery age indicator
                    _DiscoveryAgeBadge(entry: entry),

                    // User note preview
                    if (entry.userNote != null &&
                        entry.userNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing4),
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

              // Optional pet preview (cached remote observation)
              if (AppFeatureFlags.isPetEnabled) ...[
                PetMiniPreview(nodeNum: entry.nodeNum, size: 32),
                const SizedBox(width: AppTheme.spacing4),
              ],

              // Chevron
              const SizedBox(width: AppTheme.spacing4),
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
    final notifier = ref.read(nodeDexProvider.notifier);
    final nodeNum = entry.nodeNum;
    final navigator = Navigator.of(context);

    AppBottomSheet.show<void>(
      context: context,
      child: SocialTagSelector(
        currentTag: entry.socialTag,
        onTagSelected: (tag) {
          notifier.setSocialTag(nodeNum, tag);
          navigator.pop();
        },
      ),
    );
  }
}

/// Subtle discovery age indicator shown on list tiles.
///
/// Shows "new today" for nodes discovered in the last 24 hours,
/// or "discovered X days/weeks/months ago" for older entries.
class _DiscoveryAgeBadge extends StatelessWidget {
  final NodeDexEntry entry;

  const _DiscoveryAgeBadge({required this.entry});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(entry.firstSeen);
    final label = _ageLabel(age, context);

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 10,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppTheme.spacing3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: context.textTertiary.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  static String _ageLabel(Duration age, BuildContext context) {
    final l10n = context.l10n;
    if (age.inHours < 24) return l10n.nodedexAgeNewToday;
    if (age.inDays == 1) return l10n.nodedexAgeDiscoveredYesterday;
    if (age.inDays < 7) return l10n.nodedexAgeDiscoveredDaysAgo(age.inDays);
    if (age.inDays < 30) {
      return l10n.nodedexAgeDiscoveredWeeksAgo(age.inDays ~/ 7);
    }
    if (age.inDays < 365) {
      return l10n.nodedexAgeDiscoveredMonthsAgo(age.inDays ~/ 30);
    }
    return l10n.nodedexAgeDiscoveredYearsAgo(age.inDays ~/ 365);
  }
}

/// Compact metric chip showing an icon and value.
// `_MetricChip` extracted to `lib/core/widgets/metric_chip.dart` so
// MeshCanvas and any future feature can use the same primitive
// without cross-feature import or duplication.

/// Compact chip showing the radio preset a node was observed on.
class _RadioPresetChip extends StatelessWidget {
  final int presetValue;

  const _RadioPresetChip({required this.presetValue});

  @override
  Widget build(BuildContext context) {
    final preset = ObservedRadioPreset.fromProtobufValue(presetValue);
    if (preset == null) return const SizedBox.shrink();

    final color = AccentColors.emerald;
    final label = preset.label(context.l10n);

    return Tooltip(
      message: context.l10n.nodedexObservedOnPreset(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cell_tower, size: 11, color: color),
            const SizedBox(width: AppTheme.spacing3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: AppTheme.fontFamily,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip for the radio preset filter, shown in the filter chip row.
///
/// When no presets are selected, shows "Radio Preset" in the default style.
/// When presets are selected, highlights with the count of active filters.
/// Tapping opens a bottom sheet for multi-select preset filtering.
class _RadioPresetFilterChip extends ConsumerWidget {
  final Set<int> activePresets;
  final Set<int> availablePresets;

  const _RadioPresetFilterChip({
    required this.activePresets,
    required this.availablePresets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = activePresets.isNotEmpty;
    final color = isActive ? AccentColors.emerald : context.textSecondary;

    return GestureDetector(
      onTap: () => _showPresetSheet(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AccentColors.emerald.withValues(alpha: 0.15)
              : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(
            color: isActive
                ? AccentColors.emerald.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.3),
            width: isActive ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cell_tower, size: 14, color: color),
            const SizedBox(width: AppTheme.spacing4),
            Text(
              context.l10n.nodedexFilterRadioPreset,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: AppTheme.spacing5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AccentColors.emerald.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Text(
                  activePresets.length.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AccentColors.emerald,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPresetSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.l10n.nodedexRadioPresetSheetTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          _RadioPresetSheetContent(
            activePresets: activePresets,
            availablePresets: availablePresets,
          ),
        ],
      ),
    );
  }
}

/// Content of the radio preset filter bottom sheet.
///
/// Shows a list of all observed presets with checkboxes for multi-select.
/// Includes a "Clear all" option when filters are active.
class _RadioPresetSheetContent extends ConsumerWidget {
  final Set<int> activePresets;
  final Set<int> availablePresets;

  const _RadioPresetSheetContent({
    required this.activePresets,
    required this.availablePresets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live filter state so the sheet updates reactively.
    final currentFilter = ref.watch(nodeDexRadioPresetFilterProvider);
    final sorted = availablePresets.toList()..sort();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "All Presets" clear option
        _PresetOption(
          label: context.l10n.nodedexFilterRadioPresetAll,
          icon: Icons.clear_all,
          isSelected: currentFilter.isEmpty,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(nodeDexRadioPresetFilterProvider.notifier).clear();
          },
        ),
        const Divider(height: 1),
        // Individual preset options
        ...sorted.map((value) {
          final preset = ObservedRadioPreset.fromProtobufValue(value);
          if (preset == null) return const SizedBox.shrink();
          final isSelected = currentFilter.contains(value);
          return _PresetOption(
            label: preset.label(context.l10n),
            icon: Icons.cell_tower,
            isSelected: isSelected,
            color: AccentColors.emerald,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(nodeDexRadioPresetFilterProvider.notifier).toggle(value);
            },
          );
        }),
        const SizedBox(height: AppTheme.spacing8),
      ],
    );
  }
}

/// A single option row in the preset filter sheet.
class _PresetOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _PresetOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? context.accentColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : context.textSecondary,
            ),
            const SizedBox(width: AppTheme.spacing10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? activeColor : context.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: activeColor),
          ],
        ),
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
// `_StaggeredListTile` extracted to
// `lib/core/widgets/staggered_list_tile.dart` so MeshCanvas and any
// future feature can use the same primitive without duplication.

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
          taglines: [
            context.l10n.nodedexEmptyTagline1,
            context.l10n.nodedexEmptyTagline2,
            context.l10n.nodedexEmptyTagline3,
            context.l10n.nodedexEmptyTagline4,
          ],
          titlePrefix: context.l10n.nodedexEmptyTitlePrefix,
          titleKeyword: context.l10n.nodedexEmptyTitleKeyword,
          titleSuffix: context.l10n.nodedexEmptyTitleSuffix,
        ),
      );
    }

    // For filtered views, show a simpler contextual empty state
    final (icon, title, subtitle) = switch (filter) {
      NodeDexFilter.all => (
        Icons.hexagon_outlined,
        context.l10n.nodedexEmptyAllTitle,
        context.l10n.nodedexEmptyAllSubtitle,
      ),
      NodeDexFilter.tagged => (
        Icons.label_outline,
        context.l10n.nodedexEmptyTaggedTitle,
        context.l10n.nodedexEmptyTaggedSubtitle,
      ),
      NodeDexFilter.tagContact => (
        Icons.person_outline,
        context.l10n.nodedexEmptyContactTitle,
        context.l10n.nodedexEmptyContactSubtitle,
      ),
      NodeDexFilter.tagTrustedNode => (
        Icons.verified_user_outlined,
        context.l10n.nodedexEmptyTrustedNodeTitle,
        context.l10n.nodedexEmptyTrustedNodeSubtitle,
      ),
      NodeDexFilter.tagKnownRelay => (
        Icons.cell_tower,
        context.l10n.nodedexEmptyKnownRelayTitle,
        context.l10n.nodedexEmptyKnownRelaySubtitle,
      ),
      NodeDexFilter.tagFrequentPeer => (
        Icons.people_outline,
        context.l10n.nodedexEmptyFrequentPeerTitle,
        context.l10n.nodedexEmptyFrequentPeerSubtitle,
      ),
      NodeDexFilter.recent => (
        Icons.schedule,
        context.l10n.nodedexEmptyRecentTitle,
        context.l10n.nodedexEmptyRecentSubtitle,
      ),
      NodeDexFilter.wanderers => (
        Icons.explore_outlined,
        context.l10n.nodedexEmptyWanderersTitle,
        context.l10n.nodedexEmptyWanderersSubtitle,
      ),
      NodeDexFilter.beacons => (
        Icons.flare_outlined,
        context.l10n.nodedexEmptyBeaconsTitle,
        context.l10n.nodedexEmptyBeaconsSubtitle,
      ),
      NodeDexFilter.ghosts => (
        Icons.visibility_off_outlined,
        context.l10n.nodedexEmptyGhostsTitle,
        context.l10n.nodedexEmptyGhostsSubtitle,
      ),
      NodeDexFilter.sentinels => (
        Icons.shield_outlined,
        context.l10n.nodedexEmptySentinelsTitle,
        context.l10n.nodedexEmptySentinelsSubtitle,
      ),
      NodeDexFilter.relays => (
        Icons.swap_horiz,
        context.l10n.nodedexEmptyRelaysTitle,
        context.l10n.nodedexEmptyRelaysSubtitle,
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
            const SizedBox(height: AppTheme.spacing16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
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
