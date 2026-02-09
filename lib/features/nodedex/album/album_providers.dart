// SPDX-License-Identifier: GPL-3.0-or-later

// Album Providers — state management for the Collector Album system.
//
// Manages:
//   - View mode toggle (list vs album grid)
//   - Album grouping strategy (by trait, rarity, or region)
//   - Collection progress computations (rarity breakdown, trait counts)
//   - Gallery navigation state (current card index)
//
// All providers follow Riverpod 3.x patterns. No StateNotifier,
// no StateProvider, no ChangeNotifierProvider.
//
// The collection progress providers are derived (read-only) providers
// that consume nodeDexProvider and nodeDexStatsProvider. They perform
// no side effects and produce immutable snapshots of album state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../widgets/sigil_card.dart';

// =============================================================================
// View mode
// =============================================================================

/// The two browse modes available on the NodeDex screen.
enum AlbumViewMode {
  /// Traditional scrollable list with tiles.
  list,

  /// Collector album grid with card slots grouped by category.
  album,
}

/// Persisted toggle between list and album view modes.
///
/// The preference is stored in SharedPreferences under key
/// 'nodedex_view_mode'. Defaults to [AlbumViewMode.list] so
/// existing users see no change until they opt in.
class AlbumViewModeNotifier extends Notifier<AlbumViewMode> {
  static const _prefsKey = 'nodedex_view_mode';

  @override
  AlbumViewMode build() {
    _loadFromPrefs();
    return AlbumViewMode.list;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == 'album') {
      state = AlbumViewMode.album;
    }
  }

  Future<void> setMode(AlbumViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  void toggle() {
    final next = state == AlbumViewMode.list
        ? AlbumViewMode.album
        : AlbumViewMode.list;
    setMode(next);
  }
}

final albumViewModeProvider =
    NotifierProvider<AlbumViewModeNotifier, AlbumViewMode>(
      AlbumViewModeNotifier.new,
    );

// =============================================================================
// Grouping strategy
// =============================================================================

/// How cards are grouped into album pages.
enum AlbumGrouping {
  /// Group by inferred trait (Relay, Wanderer, Ghost, etc.).
  byTrait,

  /// Group by rarity tier (Legendary, Epic, Rare, etc.).
  byRarity,

  /// Group by geographic region.
  byRegion,
}

/// User-selectable grouping strategy for album pages.
///
/// Persisted in SharedPreferences under key 'album_grouping'.
/// Defaults to [AlbumGrouping.byTrait].
class AlbumGroupingNotifier extends Notifier<AlbumGrouping> {
  static const _prefsKey = 'album_grouping';

  @override
  AlbumGrouping build() {
    _loadFromPrefs();
    return AlbumGrouping.byTrait;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null) {
      for (final g in AlbumGrouping.values) {
        if (g.name == stored) {
          state = g;
          return;
        }
      }
    }
  }

  Future<void> setGrouping(AlbumGrouping grouping) async {
    state = grouping;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, grouping.name);
  }
}

final albumGroupingProvider =
    NotifierProvider<AlbumGroupingNotifier, AlbumGrouping>(
      AlbumGroupingNotifier.new,
    );

// =============================================================================
// Collection progress
// =============================================================================

/// Immutable snapshot of overall collection progress.
///
/// Derived entirely from NodeDex data — no additional storage.
/// Used by the album cover dashboard and progress indicators.
class CollectionProgress {
  /// Total unique nodes discovered.
  final int totalNodes;

  /// Breakdown by rarity tier: rarity → count.
  final Map<CardRarity, int> rarityBreakdown;

  /// Breakdown by inferred trait: trait → count.
  final Map<NodeTrait, int> traitBreakdown;

  /// Breakdown by region label: region → count.
  final Map<String, int> regionBreakdown;

  /// Number of distinct regions explored.
  final int totalRegions;

  /// Total encounters across all nodes.
  final int totalEncounters;

  /// Days since the first discovery.
  final int daysExploring;

  /// The current explorer title.
  final ExplorerTitle explorerTitle;

  /// Percentage of rarity tiers that have at least one card (0.0–1.0).
  final double rarityCompletionFraction;

  /// Percentage of trait types that have at least one card (0.0–1.0).
  final double traitCompletionFraction;

  const CollectionProgress({
    this.totalNodes = 0,
    this.rarityBreakdown = const {},
    this.traitBreakdown = const {},
    this.regionBreakdown = const {},
    this.totalRegions = 0,
    this.totalEncounters = 0,
    this.daysExploring = 0,
    this.explorerTitle = ExplorerTitle.newcomer,
    this.rarityCompletionFraction = 0.0,
    this.traitCompletionFraction = 0.0,
  });

  /// Whether at least one legendary card has been collected.
  bool get hasLegendary => (rarityBreakdown[CardRarity.legendary] ?? 0) > 0;

  /// Whether at least one epic card has been collected.
  bool get hasEpic => (rarityBreakdown[CardRarity.epic] ?? 0) > 0;

  /// The highest rarity tier achieved.
  CardRarity get highestRarity {
    for (final r in [
      CardRarity.legendary,
      CardRarity.epic,
      CardRarity.rare,
      CardRarity.uncommon,
      CardRarity.common,
    ]) {
      if ((rarityBreakdown[r] ?? 0) > 0) return r;
    }
    return CardRarity.common;
  }
}

/// Computes [CollectionProgress] from live NodeDex data.
///
/// This is a derived provider — it recomputes automatically whenever
/// the underlying nodeDex entries or stats change. No manual refresh
/// needed.
final collectionProgressProvider = Provider<CollectionProgress>((ref) {
  final entries = ref.watch(nodeDexProvider);
  final stats = ref.watch(nodeDexStatsProvider);

  if (entries.isEmpty) {
    return const CollectionProgress();
  }

  // Build rarity breakdown.
  final rarityBreakdown = <CardRarity, int>{};
  final traitBreakdown = <NodeTrait, int>{};
  final regionBreakdown = <String, int>{};

  for (final entry in entries.values) {
    // Rarity requires trait — compute it.
    final traitResult = ref.read(nodeDexTraitProvider(entry.nodeNum));
    final trait = traitResult.primary;

    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: trait,
    );
    rarityBreakdown[rarity] = (rarityBreakdown[rarity] ?? 0) + 1;

    // Trait breakdown.
    traitBreakdown[trait] = (traitBreakdown[trait] ?? 0) + 1;

    // Region breakdown.
    for (final region in entry.seenRegions) {
      regionBreakdown[region.label] = (regionBreakdown[region.label] ?? 0) + 1;
    }
  }

  // Compute completion fractions.
  // Rarity: 5 tiers total (common through legendary).
  final filledRarities = rarityBreakdown.entries
      .where((e) => e.value > 0)
      .length;
  final rarityFraction = filledRarities / CardRarity.values.length;

  // Trait: count all trait types except unknown.
  final knownTraitTypes = NodeTrait.values.where((t) => t != NodeTrait.unknown);
  final filledTraits = knownTraitTypes
      .where((t) => (traitBreakdown[t] ?? 0) > 0)
      .length;
  final traitFraction = knownTraitTypes.isEmpty
      ? 0.0
      : filledTraits / knownTraitTypes.length;

  return CollectionProgress(
    totalNodes: entries.length,
    rarityBreakdown: rarityBreakdown,
    traitBreakdown: traitBreakdown,
    regionBreakdown: regionBreakdown,
    totalRegions: stats.totalRegions,
    totalEncounters: stats.totalEncounters,
    daysExploring: stats.daysExploring,
    explorerTitle: stats.explorerTitle,
    rarityCompletionFraction: rarityFraction,
    traitCompletionFraction: traitFraction,
  );
});

// =============================================================================
// Album page data
// =============================================================================

/// A single album page — a named group of node entries.
///
/// Pages are assembled by the grouping provider and rendered as
/// sticky-header sections in the album grid view.
class AlbumPage {
  /// Display title for the page header (e.g. "Relay Nodes").
  final String title;

  /// Icon for the page header.
  final String iconKey;

  /// Entries in this page, sorted by encounter count descending.
  final List<NodeDexEntry> entries;

  /// The grouping key (trait name, rarity name, or region label).
  final String groupKey;

  const AlbumPage({
    required this.title,
    required this.iconKey,
    required this.entries,
    required this.groupKey,
  });

  /// Number of filled slots in this page.
  int get filledCount => entries.length;
}

/// Assembles album pages based on the selected grouping strategy.
///
/// Watches [albumGroupingProvider] and [nodeDexProvider] to produce
/// an ordered list of [AlbumPage] objects ready for rendering.
final albumPagesProvider = Provider<List<AlbumPage>>((ref) {
  final grouping = ref.watch(albumGroupingProvider);
  final entries = ref.watch(nodeDexProvider);

  if (entries.isEmpty) return const [];

  return switch (grouping) {
    AlbumGrouping.byTrait => _groupByTrait(ref, entries.values.toList()),
    AlbumGrouping.byRarity => _groupByRarity(ref, entries.values.toList()),
    AlbumGrouping.byRegion => _groupByRegion(entries.values.toList()),
  };
});

/// Groups entries by their inferred primary trait.
List<AlbumPage> _groupByTrait(Ref ref, List<NodeDexEntry> all) {
  final groups = <NodeTrait, List<NodeDexEntry>>{};

  for (final entry in all) {
    final traitResult = ref.read(nodeDexTraitProvider(entry.nodeNum));
    final trait = traitResult.primary;
    groups.putIfAbsent(trait, () => []).add(entry);
  }

  // Sort entries within each group by encounter count descending.
  for (final list in groups.values) {
    list.sort((a, b) => b.encounterCount.compareTo(a.encounterCount));
  }

  // Order groups by the canonical trait display order.
  final orderedTraits = [
    NodeTrait.relay,
    NodeTrait.sentinel,
    NodeTrait.beacon,
    NodeTrait.wanderer,
    NodeTrait.anchor,
    NodeTrait.courier,
    NodeTrait.drifter,
    NodeTrait.ghost,
    NodeTrait.unknown,
  ];

  final pages = <AlbumPage>[];
  for (final trait in orderedTraits) {
    final list = groups[trait];
    if (list != null && list.isNotEmpty) {
      pages.add(
        AlbumPage(
          title: '${trait.displayLabel} Nodes',
          iconKey: trait.name,
          entries: list,
          groupKey: trait.name,
        ),
      );
    }
  }

  return pages;
}

/// Groups entries by their computed rarity tier.
List<AlbumPage> _groupByRarity(Ref ref, List<NodeDexEntry> all) {
  final groups = <CardRarity, List<NodeDexEntry>>{};

  for (final entry in all) {
    final traitResult = ref.read(nodeDexTraitProvider(entry.nodeNum));
    final trait = traitResult.primary;
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: trait,
    );
    groups.putIfAbsent(rarity, () => []).add(entry);
  }

  for (final list in groups.values) {
    list.sort((a, b) => b.encounterCount.compareTo(a.encounterCount));
  }

  // Order: legendary first (most prestigious).
  final orderedRarities = [
    CardRarity.legendary,
    CardRarity.epic,
    CardRarity.rare,
    CardRarity.uncommon,
    CardRarity.common,
  ];

  final pages = <AlbumPage>[];
  for (final rarity in orderedRarities) {
    final list = groups[rarity];
    if (list != null && list.isNotEmpty) {
      pages.add(
        AlbumPage(
          title: '${rarity.label} Cards',
          iconKey: rarity.name,
          entries: list,
          groupKey: rarity.name,
        ),
      );
    }
  }

  return pages;
}

/// Groups entries by their first-seen region.
///
/// A node can appear in multiple regions. It is placed in the
/// region where it was first seen (earliest firstSeen timestamp).
/// Nodes with no region data go into an "Unknown Region" group.
List<AlbumPage> _groupByRegion(List<NodeDexEntry> all) {
  final groups = <String, List<NodeDexEntry>>{};

  for (final entry in all) {
    String regionLabel;
    if (entry.seenRegions.isEmpty) {
      regionLabel = 'Unknown Region';
    } else {
      // Pick the region with the earliest firstSeen.
      final sorted = [...entry.seenRegions]
        ..sort((a, b) => a.firstSeen.compareTo(b.firstSeen));
      regionLabel = sorted.first.label;
    }
    groups.putIfAbsent(regionLabel, () => []).add(entry);
  }

  for (final list in groups.values) {
    list.sort((a, b) => b.encounterCount.compareTo(a.encounterCount));
  }

  // Sort groups alphabetically, but put "Unknown Region" last.
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (a == 'Unknown Region') return 1;
      if (b == 'Unknown Region') return -1;
      return a.compareTo(b);
    });

  return keys.map((key) {
    return AlbumPage(
      title: key,
      iconKey: 'region',
      entries: groups[key]!,
      groupKey: key,
    );
  }).toList();
}

// =============================================================================
// Gallery state
// =============================================================================

/// Tracks the currently focused card index in the gallery view.
///
/// Reset when the gallery is opened with a new set of cards.
class GalleryIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final galleryIndexProvider = NotifierProvider<GalleryIndexNotifier, int>(
  GalleryIndexNotifier.new,
);

/// Flat list of all entries in album page order, used by the gallery.
///
/// This flattens the grouped album pages into a single ordered list
/// so the gallery can use a simple integer index for PageView navigation.
final albumFlatEntriesProvider = Provider<List<NodeDexEntry>>((ref) {
  final pages = ref.watch(albumPagesProvider);
  return pages.expand((page) => page.entries).toList();
});

/// Provides the total number of cards in the current album.
final albumCardCountProvider = Provider<int>((ref) {
  return ref.watch(albumFlatEntriesProvider).length;
});

// =============================================================================
// Card flip state
// =============================================================================

/// Tracks which cards are currently showing their back side.
///
/// Keyed by nodeNum. Cards not in the set are showing their front.
class CardFlipStateNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void toggleFlip(int nodeNum) {
    if (state.contains(nodeNum)) {
      state = {...state}..remove(nodeNum);
    } else {
      state = {...state, nodeNum};
    }
  }

  bool isFlipped(int nodeNum) => state.contains(nodeNum);

  void resetAll() => state = const {};
}

final cardFlipStateProvider = NotifierProvider<CardFlipStateNotifier, Set<int>>(
  CardFlipStateNotifier.new,
);
