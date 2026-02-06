// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Providers — Riverpod 3.x state management for the mesh field journal.
//
// Provider hierarchy:
//
// nodeDexStoreProvider (FutureProvider)
//   └── nodeDexProvider (NotifierProvider) — source of truth for all entries
//         ├── nodeDexEntryProvider(int) — single entry lookup
//         ├── nodeDexStatsProvider — aggregate statistics
//         ├── nodeDexTraitProvider(int) — computed trait for a node
//         ├── nodeDexSortedEntriesProvider — sorted list for UI
//         └── nodeDexConstellationProvider — graph data for constellation view
//
// The nodeDexProvider listens to nodesProvider for automatic discovery
// tracking. When a new node appears or an existing node updates, the
// NodeDex entry is created or refreshed without any user action.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../models/nodedex_entry.dart';
import '../services/nodedex_store.dart';
import '../services/sigil_generator.dart';
import '../services/trait_engine.dart';

// =============================================================================
// Storage Provider
// =============================================================================

/// Provides an initialized NodeDexStore instance.
///
/// The store is initialized once and shared across all providers.
/// Uses FutureProvider to handle the async init.
final nodeDexStoreProvider = FutureProvider<NodeDexStore>((ref) async {
  final store = NodeDexStore();
  await store.init();

  ref.onDispose(() {
    store.flush();
  });

  return store;
});

// =============================================================================
// Core NodeDex Provider
// =============================================================================

/// The source of truth for all NodeDex entries.
///
/// This notifier:
/// - Loads entries from persistent storage on init
/// - Listens to nodesProvider for automatic discovery tracking
/// - Updates encounter records when nodes are re-seen
/// - Tracks co-seen relationships for the constellation
/// - Persists changes via debounced writes to NodeDexStore
///
/// All UI components read from this provider for NodeDex data.
class NodeDexNotifier extends Notifier<Map<int, NodeDexEntry>> {
  NodeDexStore? _store;
  Timer? _coSeenTimer;

  /// Snapshot of the last known state, used during dispose when
  /// accessing [state] is forbidden by Riverpod's lifecycle rules.
  Map<int, NodeDexEntry>? _lastKnownState;

  /// Set of node numbers seen in the current session, used for
  /// co-seen relationship tracking.
  final Set<int> _sessionSeenNodes = {};

  /// Tracks the last encounter time per node to implement cooldown.
  final Map<int, DateTime> _lastEncounterTime = {};

  /// Minimum gap between encounter recordings for the same node.
  static const Duration _encounterCooldown = Duration(minutes: 5);

  /// Interval for co-seen relationship batch updates.
  static const Duration _coSeenFlushInterval = Duration(minutes: 2);

  @override
  Map<int, NodeDexEntry> build() {
    final storeAsync = ref.watch(nodeDexStoreProvider);
    _store = storeAsync.asData?.value;

    // Listen to node changes for automatic discovery tracking.
    ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, next) {
      if (!ref.mounted) return;
      _handleNodesUpdate(previous ?? {}, next);
    });

    ref.onDispose(() {
      _coSeenTimer?.cancel();
      // Use persistOnly to avoid setting state during dispose, which
      // would violate Riverpod's lifecycle rules.
      _flushCoSeenRelationships(persistOnly: true);
      _store?.flush();
    });

    // Initialize: load from storage and sync with current nodes.
    _init();

    return {};
  }

  Future<void> _init() async {
    if (_store == null) return;

    try {
      final entries = await _store!.loadAllAsMap();
      if (!ref.mounted) return;

      state = entries;
      _lastKnownState = entries;

      AppLogging.debug(
        'NodeDex: Loaded ${entries.length} entries from storage',
      );

      // Sync with current nodes to pick up any that were discovered
      // while NodeDex was not loaded.
      final currentNodes = ref.read(nodesProvider);
      if (currentNodes.isNotEmpty) {
        _handleNodesUpdate({}, currentNodes);
      }

      // Start periodic co-seen relationship flush.
      _coSeenTimer?.cancel();
      _coSeenTimer = Timer.periodic(_coSeenFlushInterval, (_) {
        if (ref.mounted) {
          _flushCoSeenRelationships();
        }
      });
    } catch (e) {
      AppLogging.storage('NodeDex: Error initializing: $e');
    }
  }

  /// Handle node updates from the Meshtastic protocol layer.
  ///
  /// Creates new entries for newly discovered nodes and updates
  /// encounter records for re-seen nodes.
  void _handleNodesUpdate(
    Map<int, MeshNode> previous,
    Map<int, MeshNode> current,
  ) {
    if (_store == null) return;

    final myNodeNum = ref.read(myNodeNumProvider);
    final updated = Map<int, NodeDexEntry>.from(state);
    var changed = false;

    for (final entry in current.entries) {
      final nodeNum = entry.key;
      final node = entry.value;

      // Skip our own node.
      if (nodeNum == myNodeNum) continue;

      // Skip nodes with nodeNum 0 (invalid).
      if (nodeNum == 0) continue;

      final existing = updated[nodeNum];
      final now = clock.now();

      if (existing == null) {
        // New discovery: create a fresh NodeDex entry.
        final sigil = SigilGenerator.generate(nodeNum);
        final newEntry = NodeDexEntry.discovered(
          nodeNum: nodeNum,
          timestamp: node.firstHeard ?? now,
          distance: node.distance,
          snr: node.snr,
          rssi: node.rssi,
          latitude: node.hasPosition ? node.latitude : null,
          longitude: node.hasPosition ? node.longitude : null,
          sigil: sigil,
        );

        // Add region if we can determine one.
        final withRegion = _addRegionFromNode(newEntry, node);
        updated[nodeNum] = withRegion;
        _lastEncounterTime[nodeNum] = now;
        _sessionSeenNodes.add(nodeNum);
        changed = true;
      } else {
        // Existing node: check if we should record a new encounter.
        final lastEncounter = _lastEncounterTime[nodeNum];
        final shouldRecord =
            lastEncounter == null ||
            now.difference(lastEncounter) >= _encounterCooldown;

        if (shouldRecord) {
          var updatedEntry = existing.recordEncounter(
            timestamp: now,
            distance: node.distance,
            snr: node.snr,
            rssi: node.rssi,
            latitude: node.hasPosition ? node.latitude : null,
            longitude: node.hasPosition ? node.longitude : null,
          );

          // Ensure sigil is generated if missing (e.g., from older data).
          if (updatedEntry.sigil == null) {
            updatedEntry = updatedEntry.copyWith(
              sigil: SigilGenerator.generate(nodeNum),
            );
          }

          // Update region data.
          updatedEntry = _addRegionFromNode(updatedEntry, node);

          updated[nodeNum] = updatedEntry;
          _lastEncounterTime[nodeNum] = now;
          _sessionSeenNodes.add(nodeNum);
          changed = true;
        }
      }
    }

    if (changed) {
      state = updated;
      _lastKnownState = updated;
      // Persist changed entries.
      final changedEntries = <NodeDexEntry>[];
      for (final nodeNum in current.keys) {
        final entry = updated[nodeNum];
        if (entry != null) {
          changedEntries.add(entry);
        }
      }
      if (changedEntries.isNotEmpty) {
        _store!.saveEntries(changedEntries);
      }
    }
  }

  /// Add region information to an entry based on node data.
  ///
  /// Uses position-derived geohash prefix when available, or falls
  /// back to the LoRa region code from device configuration.
  NodeDexEntry _addRegionFromNode(NodeDexEntry entry, MeshNode node) {
    if (node.hasPosition && node.latitude != null && node.longitude != null) {
      // Use a coarse geohash (3-char precision = ~78km cells) as region ID.
      final regionId = _coarseGeohash(node.latitude!, node.longitude!);
      final label = _regionLabel(node.latitude!, node.longitude!);
      return entry.addRegion(regionId, label);
    }
    return entry;
  }

  /// Generate a coarse geohash-like region identifier.
  ///
  /// Uses a simple grid-based approach rather than full geohash
  /// to keep the implementation lightweight. Each cell is roughly
  /// 1 degree x 1 degree (~111km at the equator).
  String _coarseGeohash(double lat, double lon) {
    // Round to 1-degree grid.
    final latGrid = lat.floor();
    final lonGrid = lon.floor();
    return 'g${latGrid}_$lonGrid';
  }

  /// Generate a human-readable region label from coordinates.
  ///
  /// Uses cardinal direction and degree range for now.
  /// A future version could use reverse geocoding.
  String _regionLabel(double lat, double lon) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    final latDeg = lat.abs().floor();
    final lonDeg = lon.abs().floor();
    return '$latDeg\u00B0$ns $lonDeg\u00B0$ew';
  }

  /// Flush co-seen relationships for all nodes seen this session.
  ///
  /// For each pair of nodes seen in this session, increments their
  /// co-seen counter. This powers the constellation visualization.
  /// Flush co-seen relationships to state and storage.
  ///
  /// When [persistOnly] is true (e.g. during dispose), the method writes
  /// directly to the store without setting [state], which would violate
  /// Riverpod's lifecycle rules. During normal periodic flushes,
  /// [persistOnly] is false and both state and storage are updated.
  void _flushCoSeenRelationships({bool persistOnly = false}) {
    if (_sessionSeenNodes.length < 2) return;

    // During dispose (persistOnly), reading `state` is forbidden by Riverpod.
    // Use the store's last-known cache instead so we can still persist
    // relationships that were accumulated during this session.
    final Map<int, NodeDexEntry> source;
    if (persistOnly) {
      // _lastKnownState is snapshotted whenever state is set normally.
      if (_lastKnownState == null || _lastKnownState!.isEmpty) {
        _sessionSeenNodes.clear();
        return;
      }
      source = _lastKnownState!;
    } else {
      source = state;
    }

    final nodeList = _sessionSeenNodes.toList();
    final updated = Map<int, NodeDexEntry>.from(source);
    var changed = false;

    for (int i = 0; i < nodeList.length; i++) {
      for (int j = i + 1; j < nodeList.length; j++) {
        final a = nodeList[i];
        final b = nodeList[j];

        final entryA = updated[a];
        final entryB = updated[b];

        if (entryA != null) {
          updated[a] = entryA.addCoSeen(b);
          changed = true;
        }
        if (entryB != null) {
          updated[b] = entryB.addCoSeen(a);
          changed = true;
        }
      }
    }

    if (changed) {
      if (!persistOnly) {
        state = updated;
        _lastKnownState = updated;
      }
      _store?.saveEntries(updated.values.toList());
    }

    // Clear session tracking for the next interval.
    _sessionSeenNodes.clear();
  }

  // ---------------------------------------------------------------------------
  // Public mutation methods
  // ---------------------------------------------------------------------------

  /// Set the social tag for a node.
  void setSocialTag(int nodeNum, NodeSocialTag? tag) {
    final entry = state[nodeNum];
    if (entry == null) return;

    final updated = tag != null
        ? entry.copyWith(socialTag: tag)
        : entry.copyWith(clearSocialTag: true);

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);
  }

  /// Set the user note for a node.
  void setUserNote(int nodeNum, String? note) {
    final entry = state[nodeNum];
    if (entry == null) return;

    final trimmed = note?.trim();
    final updated = (trimmed == null || trimmed.isEmpty)
        ? entry.copyWith(clearUserNote: true)
        : entry.copyWith(
            userNote: trimmed.length > 280
                ? trimmed.substring(0, 280)
                : trimmed,
          );

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);
  }

  /// Increment the message count for a node and its co-seen edges.
  ///
  /// In addition to incrementing the node's own message count, this
  /// also increments [CoSeenRelationship.messageCount] for every
  /// co-seen relationship between this node and other nodes that are
  /// currently active in the session. This ensures per-edge message
  /// counts accumulate naturally as messages flow between nodes that
  /// are co-present on the mesh.
  void recordMessage(int nodeNum, {int count = 1}) {
    final entry = state[nodeNum];
    if (entry == null) return;

    var updated = entry.incrementMessages(by: count);

    // Increment per-edge message counts for all session peers that
    // have an existing co-seen relationship with this node.
    if (_sessionSeenNodes.contains(nodeNum)) {
      for (final peerNum in _sessionSeenNodes) {
        if (peerNum == nodeNum) continue;
        // Only increment if the relationship already exists — we do not
        // create new co-seen relationships from message activity alone.
        if (updated.coSeenNodes.containsKey(peerNum)) {
          updated = updated.incrementCoSeenMessages(peerNum, by: count);
        }
      }
    }

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);
  }

  /// Force a refresh from storage.
  Future<void> refresh() async {
    if (_store == null) return;

    try {
      final entries = await _store!.loadAllAsMap();
      if (!ref.mounted) return;
      state = entries;
      _lastKnownState = entries;
    } catch (e) {
      AppLogging.storage('NodeDex: Error refreshing: $e');
    }
  }

  /// Clear all NodeDex data.
  Future<void> clearAll() async {
    state = {};
    _lastKnownState = {};
    _sessionSeenNodes.clear();
    _lastEncounterTime.clear();
    await _store?.clearAll();
  }

  /// Export all entries as JSON.
  Future<String?> exportJson() async {
    return _store?.exportJson();
  }

  /// Import entries from JSON.
  Future<int> importJson(String jsonString) async {
    final count = await _store?.importJson(jsonString) ?? 0;
    if (count > 0) {
      await refresh();
    }
    return count;
  }
}

final nodeDexProvider =
    NotifierProvider<NodeDexNotifier, Map<int, NodeDexEntry>>(
      NodeDexNotifier.new,
    );

// =============================================================================
// Derived Providers
// =============================================================================

/// Provider for a single NodeDex entry by node number.
///
/// Returns null if the node has not been discovered yet.
final nodeDexEntryProvider = Provider.family<NodeDexEntry?, int>((
  ref,
  nodeNum,
) {
  final entries = ref.watch(nodeDexProvider);
  return entries[nodeNum];
});

/// Provider for the computed trait of a specific node.
///
/// Combines NodeDex encounter history with live MeshNode telemetry
/// to produce a trait classification.
final nodeDexTraitProvider = Provider.family<TraitResult, int>((ref, nodeNum) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return const TraitResult(primary: NodeTrait.unknown, confidence: 1.0);
  }

  // Get live telemetry from the nodes provider for richer inference.
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];

  return TraitEngine.infer(
    entry: entry,
    role: node?.role,
    uptimeSeconds: node?.uptimeSeconds,
    channelUtilization: node?.channelUtilization,
    airUtilTx: node?.airUtilTx,
  );
});

/// Aggregate statistics across all NodeDex entries.
///
/// Recomputed whenever entries change. Used for the stats header
/// on the main NodeDex screen and for explorer title derivation.
final nodeDexStatsProvider = Provider<NodeDexStats>((ref) {
  final entries = ref.watch(nodeDexProvider);
  if (entries.isEmpty) {
    return const NodeDexStats();
  }

  final allEntries = entries.values.toList();

  // Compute aggregate stats.
  double? longestDistance;
  int totalEncounters = 0;
  DateTime? oldest;
  DateTime? newest;
  int? bestSnr;
  int? bestRssi;
  final allRegionIds = <String>{};
  final traitCounts = <NodeTrait, int>{};
  final tagCounts = <NodeSocialTag, int>{};

  for (final entry in allEntries) {
    // Distance.
    if (entry.maxDistanceSeen != null) {
      if (longestDistance == null || entry.maxDistanceSeen! > longestDistance) {
        longestDistance = entry.maxDistanceSeen;
      }
    }

    // Encounters.
    totalEncounters += entry.encounterCount;

    // Date range.
    if (oldest == null || entry.firstSeen.isBefore(oldest)) {
      oldest = entry.firstSeen;
    }
    if (newest == null || entry.firstSeen.isAfter(newest)) {
      newest = entry.firstSeen;
    }

    // Best signals.
    if (entry.bestSnr != null) {
      if (bestSnr == null || entry.bestSnr! > bestSnr) {
        bestSnr = entry.bestSnr;
      }
    }
    if (entry.bestRssi != null) {
      if (bestRssi == null || entry.bestRssi! > bestRssi) {
        bestRssi = entry.bestRssi;
      }
    }

    // Regions.
    for (final region in entry.seenRegions) {
      allRegionIds.add(region.regionId);
    }

    // Traits (computed per node).
    final trait = ref.read(nodeDexTraitProvider(entry.nodeNum));
    traitCounts[trait.primary] = (traitCounts[trait.primary] ?? 0) + 1;

    // Social tags.
    if (entry.socialTag != null) {
      tagCounts[entry.socialTag!] = (tagCounts[entry.socialTag!] ?? 0) + 1;
    }
  }

  return NodeDexStats(
    totalNodes: allEntries.length,
    totalRegions: allRegionIds.length,
    longestDistance: longestDistance,
    totalEncounters: totalEncounters,
    oldestDiscovery: oldest,
    newestDiscovery: newest,
    traitDistribution: traitCounts,
    socialTagDistribution: tagCounts,
    bestSnrOverall: bestSnr,
    bestRssiOverall: bestRssi,
  );
});

/// Sorting options for the NodeDex entry list.
enum NodeDexSortOrder {
  /// Most recently seen first.
  lastSeen,

  /// Most recently discovered first.
  firstSeen,

  /// Most encounters first.
  encounters,

  /// Longest distance first.
  distance,

  /// Alphabetical by display name.
  name,
}

/// Filter options for the NodeDex entry list.
enum NodeDexFilter {
  /// Show all entries.
  all,

  /// Only entries with a social tag.
  tagged,

  /// Only recently discovered (last 24h).
  recent,

  /// Only entries with the Wanderer trait.
  wanderers,

  /// Only entries with the Beacon trait.
  beacons,

  /// Only entries with the Ghost trait.
  ghosts,

  /// Only entries with the Sentinel trait.
  sentinels,

  /// Only entries with the Relay trait.
  relays,
}

/// Notifier for the current sort order.
class NodeDexSortNotifier extends Notifier<NodeDexSortOrder> {
  @override
  NodeDexSortOrder build() => NodeDexSortOrder.lastSeen;

  void setOrder(NodeDexSortOrder order) => state = order;
}

final nodeDexSortProvider =
    NotifierProvider<NodeDexSortNotifier, NodeDexSortOrder>(
      NodeDexSortNotifier.new,
    );

/// Notifier for the current filter.
class NodeDexFilterNotifier extends Notifier<NodeDexFilter> {
  @override
  NodeDexFilter build() => NodeDexFilter.all;

  void setFilter(NodeDexFilter filter) => state = filter;
}

final nodeDexFilterProvider =
    NotifierProvider<NodeDexFilterNotifier, NodeDexFilter>(
      NodeDexFilterNotifier.new,
    );

/// Search query for the NodeDex list.
class NodeDexSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final nodeDexSearchProvider = NotifierProvider<NodeDexSearchNotifier, String>(
  NodeDexSearchNotifier.new,
);

/// Sorted and filtered list of NodeDex entries for the main screen.
///
/// Combines the entries from nodeDexProvider with the current sort order,
/// filter, and search query. Returns a list of (NodeDexEntry, MeshNode?)
/// pairs so the UI has access to both enriched and live data.
final nodeDexSortedEntriesProvider = Provider<List<(NodeDexEntry, MeshNode?)>>((
  ref,
) {
  final entries = ref.watch(nodeDexProvider);
  final nodes = ref.watch(nodesProvider);
  final sort = ref.watch(nodeDexSortProvider);
  final filter = ref.watch(nodeDexFilterProvider);
  final search = ref.watch(nodeDexSearchProvider).toLowerCase();

  if (entries.isEmpty) return [];

  // Build paired list.
  var paired = entries.values.map((entry) {
    final node = nodes[entry.nodeNum];
    return (entry, node);
  }).toList();

  // Apply filter.
  paired = _applyFilter(paired, filter, ref);

  // Apply search.
  if (search.isNotEmpty) {
    paired = paired.where((pair) {
      final (entry, node) = pair;
      final name = node?.displayName.toLowerCase() ?? '';
      final hexId = entry.nodeNum.toRadixString(16).toLowerCase();
      final note = entry.userNote?.toLowerCase() ?? '';
      final tag = entry.socialTag?.displayLabel.toLowerCase() ?? '';
      return name.contains(search) ||
          hexId.contains(search) ||
          note.contains(search) ||
          tag.contains(search);
    }).toList();
  }

  // Apply sort.
  paired.sort((a, b) {
    final (entryA, nodeA) = a;
    final (entryB, nodeB) = b;

    return switch (sort) {
      NodeDexSortOrder.lastSeen => entryB.lastSeen.compareTo(entryA.lastSeen),
      NodeDexSortOrder.firstSeen => entryB.firstSeen.compareTo(
        entryA.firstSeen,
      ),
      NodeDexSortOrder.encounters => entryB.encounterCount.compareTo(
        entryA.encounterCount,
      ),
      NodeDexSortOrder.distance => _compareDistance(entryA, entryB),
      NodeDexSortOrder.name => (nodeA?.displayName ?? '').compareTo(
        nodeB?.displayName ?? '',
      ),
    };
  });

  return paired;
});

/// Compare two entries by max distance (descending, nulls last).
int _compareDistance(NodeDexEntry a, NodeDexEntry b) {
  if (a.maxDistanceSeen == null && b.maxDistanceSeen == null) return 0;
  if (a.maxDistanceSeen == null) return 1;
  if (b.maxDistanceSeen == null) return -1;
  return b.maxDistanceSeen!.compareTo(a.maxDistanceSeen!);
}

/// Apply the current filter to the entry list.
List<(NodeDexEntry, MeshNode?)> _applyFilter(
  List<(NodeDexEntry, MeshNode?)> entries,
  NodeDexFilter filter,
  Ref ref,
) {
  if (filter == NodeDexFilter.all) return entries;

  return entries.where((pair) {
    final (entry, _) = pair;
    return switch (filter) {
      NodeDexFilter.all => true,
      NodeDexFilter.tagged => entry.socialTag != null,
      NodeDexFilter.recent => entry.isRecentlyDiscovered,
      NodeDexFilter.wanderers =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.wanderer,
      NodeDexFilter.beacons =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.beacon,
      NodeDexFilter.ghosts =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.ghost,
      NodeDexFilter.sentinels =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.sentinel,
      NodeDexFilter.relays =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.relay,
    };
  }).toList();
}

// =============================================================================
// Constellation Provider
// =============================================================================

/// A node in the constellation graph.
class ConstellationNode {
  /// The node number.
  final int nodeNum;

  /// Display name for the node.
  final String displayName;

  /// The sigil data for visual rendering.
  final SigilData? sigil;

  /// The primary trait.
  final NodeTrait trait;

  /// Number of total connections (co-seen relationships).
  final int connectionCount;

  /// X position in the constellation (0.0 to 1.0, deterministic).
  final double x;

  /// Y position in the constellation (0.0 to 1.0, deterministic).
  final double y;

  const ConstellationNode({
    required this.nodeNum,
    required this.displayName,
    this.sigil,
    required this.trait,
    required this.connectionCount,
    required this.x,
    required this.y,
  });
}

/// An edge in the constellation graph.
class ConstellationEdge {
  /// Source node number.
  final int from;

  /// Target node number.
  final int to;

  /// Weight (co-seen count) — higher means stronger connection.
  final int weight;

  /// When this co-seen relationship was first recorded.
  final DateTime? firstSeen;

  /// When this co-seen relationship was most recently recorded.
  final DateTime? lastSeen;

  /// Number of messages exchanged while both nodes were co-seen.
  final int messageCount;

  const ConstellationEdge({
    required this.from,
    required this.to,
    required this.weight,
    this.firstSeen,
    this.lastSeen,
    this.messageCount = 0,
  });

  /// Duration of the relationship from first to last sighting.
  Duration? get relationshipAge {
    if (firstSeen == null || lastSeen == null) return null;
    return lastSeen!.difference(firstSeen!);
  }

  /// Time since the last co-sighting.
  Duration? get timeSinceLastSeen {
    if (lastSeen == null) return null;
    return DateTime.now().difference(lastSeen!);
  }
}

/// The complete constellation graph data.
class ConstellationData {
  /// All nodes in the constellation.
  final List<ConstellationNode> nodes;

  /// All edges (connections) between nodes.
  final List<ConstellationEdge> edges;

  /// Maximum edge weight for normalization.
  final int maxWeight;

  const ConstellationData({
    this.nodes = const [],
    this.edges = const [],
    this.maxWeight = 1,
  });

  bool get isEmpty => nodes.isEmpty;
  int get nodeCount => nodes.length;
  int get edgeCount => edges.length;
}

/// Provider for the constellation graph data.
///
/// Builds a force-directed-like layout using deterministic positioning
/// based on node numbers. The positions are stable — they don't change
/// between rebuilds unless nodes are added or removed.
final nodeDexConstellationProvider = Provider<ConstellationData>((ref) {
  final entries = ref.watch(nodeDexProvider);
  final nodes = ref.watch(nodesProvider);

  if (entries.isEmpty) {
    return const ConstellationData();
  }

  final allEntries = entries.values.toList();

  // Build edges from co-seen relationships.
  final edgeSet = <String, ConstellationEdge>{};
  int maxWeight = 1;

  for (final entry in allEntries) {
    for (final coSeen in entry.coSeenNodes.entries) {
      final other = coSeen.key;
      final relationship = coSeen.value;
      final weight = relationship.count;

      // Only include edges where both nodes exist in the dex.
      if (!entries.containsKey(other)) continue;

      // Create a canonical edge key to avoid duplicates.
      final a = entry.nodeNum < other ? entry.nodeNum : other;
      final b = entry.nodeNum < other ? other : entry.nodeNum;
      final key = '${a}_$b';

      if (!edgeSet.containsKey(key) || edgeSet[key]!.weight < weight) {
        edgeSet[key] = ConstellationEdge(
          from: a,
          to: b,
          weight: weight,
          firstSeen: relationship.firstSeen,
          lastSeen: relationship.lastSeen,
          messageCount: relationship.messageCount,
        );
        if (weight > maxWeight) maxWeight = weight;
      }
    }
  }

  // Build constellation nodes with deterministic positions.
  // Uses a hash-based spiral layout: nodes are placed on a spiral
  // pattern where the angle and radius are derived from the node number.
  // This ensures stable, non-overlapping positions.
  final constellationNodes = <ConstellationNode>[];
  final nodeCount = allEntries.length;

  for (int i = 0; i < nodeCount; i++) {
    final entry = allEntries[i];
    final node = nodes[entry.nodeNum];
    final trait = ref.read(nodeDexTraitProvider(entry.nodeNum));

    // Deterministic position from node number hash.
    final hash = _positionHash(entry.nodeNum);
    final angle = (hash & 0xFFFF) / 65535.0 * 3.14159265358979 * 2.0;
    final radius = 0.15 + ((hash >> 16) & 0xFFFF) / 65535.0 * 0.35;

    // Convert polar to cartesian, centered at (0.5, 0.5).
    final x = 0.5 + radius * _fastCos(angle);
    final y = 0.5 + radius * _fastSin(angle);

    constellationNodes.add(
      ConstellationNode(
        nodeNum: entry.nodeNum,
        displayName: node?.displayName ?? 'Node ${entry.nodeNum}',
        sigil: entry.sigil,
        trait: trait.primary,
        connectionCount: entry.coSeenCount,
        x: x.clamp(0.05, 0.95),
        y: y.clamp(0.05, 0.95),
      ),
    );
  }

  return ConstellationData(
    nodes: constellationNodes,
    edges: edgeSet.values.toList(),
    maxWeight: maxWeight,
  );
});

/// Hash function for deterministic constellation positioning.
int _positionHash(int nodeNum) {
  int h = nodeNum & 0xFFFFFFFF;
  h ^= h >> 16;
  h = (h * 0x45d9f3b) & 0xFFFFFFFF;
  h ^= h >> 16;
  h = (h * 0x45d9f3b) & 0xFFFFFFFF;
  h ^= h >> 16;
  return h;
}

/// Fast sine approximation for constellation layout.
double _fastSin(double x) {
  const pi = 3.14159265358979;
  const twoPi = pi * 2.0;
  x = x % twoPi;
  if (x > pi) x -= twoPi;
  if (x < -pi) x += twoPi;
  final num = 16.0 * x * (pi - x);
  final den = 5.0 * pi * pi - 4.0 * x * (pi - x);
  if (den.abs() < 1e-10) return 0.0;
  return num / den;
}

/// Fast cosine approximation for constellation layout.
double _fastCos(double x) {
  return _fastSin(x + 3.14159265358979 / 2.0);
}
