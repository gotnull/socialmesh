// SPDX-License-Identifier: GPL-3.0-or-later

/// Riverpod 3.x providers for MQTT ↔ NodeDex integration.
///
/// These providers manage:
/// - [RemoteSighting] state — opt-in records of nodes seen via the broker
/// - [RemoteSightingStats] — aggregate statistics for the status panel
/// - [NodeDiscoverySource] filtering — Local/Remote/Mixed filters
/// - Remote badge visibility — controls the "Remote" badge on node cards
///
/// All remote sighting recording is gated behind the Global Layer
/// privacy setting [GlobalLayerPrivacySettings.allowInboundGlobal].
/// When that toggle is OFF, no remote sightings are recorded and
/// the providers return empty/default state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/mqtt/mqtt_remote_sighting.dart';
import 'mqtt_providers.dart';

// ---------------------------------------------------------------------------
// Remote Sightings Notifier
// ---------------------------------------------------------------------------

/// Notifier that manages the in-memory list of [RemoteSighting] records.
///
/// Sightings are stored in memory only (not persisted to disk) because
/// they are transient observations that can be re-received from the
/// broker. The list is bounded by [maxRemoteSightingsRetained] to
/// prevent unbounded memory growth.
///
/// Recording is gated by the Global Layer privacy setting for inbound
/// global data. If that toggle is OFF, [recordSighting] is a no-op.
class RemoteSightingsNotifier extends Notifier<List<RemoteSighting>> {
  /// Tracks the last sighting time per node to enforce cooldown.
  final Map<int, DateTime> _lastSightingTime = {};

  @override
  List<RemoteSighting> build() => const [];

  /// Records a new remote sighting if privacy settings allow it.
  ///
  /// Returns `true` if the sighting was recorded, `false` if it was
  /// skipped due to privacy settings, cooldown, or other guards.
  bool recordSighting(RemoteSighting sighting) {
    // Gate: check that inbound global data is allowed
    final configAsync = ref.read(globalLayerConfigProvider);
    final config = configAsync.value;
    if (config == null || !config.privacy.allowInboundGlobal) {
      return false;
    }

    // Gate: check that global layer is enabled and setup is complete
    if (!config.enabled || !config.setupComplete) {
      return false;
    }

    // Cooldown: skip if we recently recorded a sighting for this node
    final lastTime = _lastSightingTime[sighting.nodeNum];
    if (lastTime != null) {
      final elapsed = sighting.timestamp.difference(lastTime);
      if (elapsed < remoteSightingCooldown) {
        return false;
      }
    }

    // Record the sighting
    _lastSightingTime[sighting.nodeNum] = sighting.timestamp;

    final updated = [...state, sighting];

    // Evict oldest entries if over the retention limit
    if (updated.length > maxRemoteSightingsRetained) {
      final excess = updated.length - maxRemoteSightingsRetained;
      state = updated.sublist(excess);
    } else {
      state = updated;
    }

    AppLogging.settings(
      'GlobalLayer: recorded remote sighting for node '
      '${sighting.nodeNum} via ${sighting.topic}',
    );

    return true;
  }

  /// Records multiple sightings in a batch.
  ///
  /// Returns the count of sightings that were actually recorded
  /// (after privacy and cooldown filtering).
  int recordBatch(List<RemoteSighting> sightings) {
    int recorded = 0;
    for (final sighting in sightings) {
      if (recordSighting(sighting)) recorded++;
    }
    return recorded;
  }

  /// Returns the most recent sighting for a specific node, if any.
  RemoteSighting? latestForNode(int nodeNum) {
    for (var i = state.length - 1; i >= 0; i--) {
      if (state[i].nodeNum == nodeNum) return state[i];
    }
    return null;
  }

  /// Returns all sightings for a specific node.
  List<RemoteSighting> sightingsForNode(int nodeNum) {
    return state.where((s) => s.nodeNum == nodeNum).toList(growable: false);
  }

  /// Returns the set of all unique node numbers seen via remote sightings.
  Set<int> get remoteNodeNums {
    return state.map((s) => s.nodeNum).toSet();
  }

  /// Clears all recorded sightings and resets cooldown tracking.
  void clear() {
    _lastSightingTime.clear();
    state = const [];
    AppLogging.settings('GlobalLayer: cleared all remote sightings');
  }

  /// Removes sightings older than [maxAge].
  ///
  /// Called periodically to prevent stale data from accumulating.
  void pruneOlderThan(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    final pruned = state.where((s) => s.timestamp.isAfter(cutoff)).toList();
    if (pruned.length != state.length) {
      final removed = state.length - pruned.length;
      state = pruned;

      // Also clean up cooldown map entries for pruned nodes
      _lastSightingTime.removeWhere((_, time) => time.isBefore(cutoff));

      AppLogging.settings(
        'GlobalLayer: pruned $removed stale remote sightings',
      );
    }
  }
}

/// Provider for the list of remote sightings.
final remoteSightingsProvider =
    NotifierProvider<RemoteSightingsNotifier, List<RemoteSighting>>(
      RemoteSightingsNotifier.new,
    );

// ---------------------------------------------------------------------------
// Remote Sighting Stats
// ---------------------------------------------------------------------------

/// Derived provider that computes aggregate statistics from the
/// current list of remote sightings.
///
/// Rebuilds whenever the sightings list changes.
final remoteSightingStatsProvider = Provider<RemoteSightingStats>((ref) {
  final sightings = ref.watch(remoteSightingsProvider);
  return RemoteSightingStats.fromSightings(sightings);
});

// ---------------------------------------------------------------------------
// Discovery Source Resolution
// ---------------------------------------------------------------------------

/// Resolves the [NodeDiscoverySource] for a given node number by
/// checking whether the node has been seen locally, remotely, or both.
///
/// This provider is parameterised by node number using `.call(nodeNum)`.
///
/// Usage:
/// ```dart
/// final source = ref.watch(nodeDiscoverySourceProvider(nodeNum));
/// ```
final nodeDiscoverySourceProvider = Provider.family<NodeDiscoverySource, int>((
  ref,
  nodeNum,
) {
  final remoteSightings = ref.watch(remoteSightingsProvider);
  final hasRemote = remoteSightings.any((s) => s.nodeNum == nodeNum);

  // We treat all nodes in the NodeDex as locally discovered unless
  // they also appear in remote sightings (making them "mixed") or
  // only appear in remote sightings (making them "remote").
  //
  // The actual local/remote determination for NodeDex entries is
  // handled by the filtered entries provider below, which checks
  // whether the node exists in the local NodeDex state.
  if (hasRemote) {
    return NodeDiscoverySource.mixed;
  }
  return NodeDiscoverySource.local;
});

// ---------------------------------------------------------------------------
// Discovery Source Filter
// ---------------------------------------------------------------------------

/// Filter for the NodeDex based on discovery source.
///
/// When set to [NodeDiscoverySource.local], only locally-discovered
/// nodes are shown. When [NodeDiscoverySource.remote], only nodes
/// seen via the broker. When [NodeDiscoverySource.mixed], only nodes
/// seen via both channels. When null, no source filtering is applied.
class DiscoverySourceFilterNotifier extends Notifier<NodeDiscoverySource?> {
  @override
  NodeDiscoverySource? build() => null; // No filter by default

  void setFilter(NodeDiscoverySource? source) => state = source;

  void clear() => state = null;

  void toggle(NodeDiscoverySource source) {
    state = state == source ? null : source;
  }
}

/// Provider for the current discovery source filter.
final discoverySourceFilterProvider =
    NotifierProvider<DiscoverySourceFilterNotifier, NodeDiscoverySource?>(
      DiscoverySourceFilterNotifier.new,
    );

// ---------------------------------------------------------------------------
// Remote Node Numbers
// ---------------------------------------------------------------------------

/// Set of node numbers that have been seen via remote sightings.
///
/// Used by UI components to efficiently check whether a node should
/// show a "Remote" badge without iterating the full sightings list.
final remoteNodeNumsProvider = Provider<Set<int>>((ref) {
  final sightings = ref.watch(remoteSightingsProvider);
  return sightings.map((s) => s.nodeNum).toSet();
});

/// Whether a specific node has been seen via remote sightings.
///
/// Convenience family provider for badge visibility.
///
/// Usage:
/// ```dart
/// final isRemote = ref.watch(isRemoteNodeProvider(nodeNum));
/// ```
final isRemoteNodeProvider = Provider.family<bool, int>((ref, nodeNum) {
  final remoteNodes = ref.watch(remoteNodeNumsProvider);
  return remoteNodes.contains(nodeNum);
});

// ---------------------------------------------------------------------------
// Remote Sightings Enabled
// ---------------------------------------------------------------------------

/// Whether remote sightings recording is currently enabled.
///
/// This is true when:
/// 1. Global Layer setup is complete
/// 2. Global Layer is enabled
/// 3. The "Allow Inbound Global" privacy toggle is ON
///
/// UI can use this to show/hide remote sighting related controls.
final remoteSightingsEnabledProvider = Provider<bool>((ref) {
  final configAsync = ref.watch(globalLayerConfigProvider);
  return configAsync.whenOrNull(
        data: (config) =>
            config.setupComplete &&
            config.enabled &&
            config.privacy.allowInboundGlobal,
      ) ??
      false;
});

// ---------------------------------------------------------------------------
// Remote Sighting Count Badge
// ---------------------------------------------------------------------------

/// The number of unique remote nodes sighted — used for badge displays
/// in the NodeDex and Global Layer status screen.
final remoteSightingCountProvider = Provider<int>((ref) {
  final stats = ref.watch(remoteSightingStatsProvider);
  return stats.uniqueNodes;
});

/// Whether there are any recent remote sightings (last hour).
///
/// Used to show activity indicators on the Global Layer status panel
/// and NodeDex filter chips.
final hasRecentRemoteSightingsProvider = Provider<bool>((ref) {
  final stats = ref.watch(remoteSightingStatsProvider);
  return stats.recentSightings > 0;
});
