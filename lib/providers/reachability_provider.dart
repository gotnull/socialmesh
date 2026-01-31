// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mesh_models.dart';
import '../models/reachability_models.dart';
import '../utils/reachability_score.dart';
import 'app_providers.dart';

/// Provider for node reachability data storage.
///
/// This stores passively observed reachability metadata for each node.
/// Data is collected from packet observations without any probing traffic.
final nodeReachabilityDataProvider =
    NotifierProvider<
      NodeReachabilityDataNotifier,
      Map<int, NodeReachabilityData>
    >(NodeReachabilityDataNotifier.new);

/// Notifier that manages per-node reachability observation data.
class NodeReachabilityDataNotifier
    extends Notifier<Map<int, NodeReachabilityData>> {
  @override
  Map<int, NodeReachabilityData> build() {
    return {};
  }

  /// Get or create reachability data for a node.
  NodeReachabilityData getOrCreate(int nodeNum) {
    return state[nodeNum] ?? NodeReachabilityData.empty(nodeNum);
  }

  /// Update reachability data for a node.
  void update(int nodeNum, NodeReachabilityData data) {
    state = {...state, nodeNum: data};
  }

  /// Record a direct RF packet observation from a node.
  void recordDirectPacket(int nodeNum, {double? rssi, double? snr}) {
    var data = getOrCreate(nodeNum).recordDirectPacket();
    if (rssi != null) {
      data = data.updateRssi(rssi);
    }
    if (snr != null) {
      data = data.updateSnr(snr);
    }
    update(nodeNum, data);
  }

  /// Record an indirect (relayed) packet observation from a node.
  void recordIndirectPacket(
    int nodeNum,
    int hopCount, {
    double? rssi,
    double? snr,
  }) {
    var data = getOrCreate(nodeNum).recordIndirectPacket(hopCount);
    if (rssi != null) {
      data = data.updateRssi(rssi);
    }
    if (snr != null) {
      data = data.updateSnr(snr);
    }
    update(nodeNum, data);
  }

  /// Record a DM first-hop ack result.
  void recordDmAck(int nodeNum, {required bool success}) {
    final data = getOrCreate(nodeNum).recordDmAck(success: success);
    update(nodeNum, data);
  }

  /// Clear all reachability data.
  void clear() {
    state = {};
  }
}

/// A computed view of a node with its reachability result.
class NodeWithReachability {
  final MeshNode node;
  final ReachabilityResult reachability;
  final NodeReachabilityData? observationData;

  const NodeWithReachability({
    required this.node,
    required this.reachability,
    this.observationData,
  });

  /// Whether this node is the local device.
  bool get isLocalDevice => false; // Set by the provider

  /// Sort key for ordering nodes by reachability (higher first).
  double get sortKey => reachability.score;
}

/// Provider for computed reachability results for all nodes.
///
/// This combines MeshNode data with reachability observations to produce
/// a sorted list of nodes with their reach likelihood assessments.
final nodesWithReachabilityProvider = Provider<List<NodeWithReachability>>((
  ref,
) {
  final nodes = ref.watch(nodesProvider);
  final reachabilityData = ref.watch(nodeReachabilityDataProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  final results = <NodeWithReachability>[];

  for (final entry in nodes.entries) {
    final nodeNum = entry.key;
    final node = entry.value;

    // Skip the local device - we don't assess reachability to ourselves
    if (nodeNum == myNodeNum) continue;

    // Get observation data if available
    final obsData = reachabilityData[nodeNum];

    // Calculate last heard seconds from DateTime
    int? lastHeardSecs;
    if (node.lastHeard != null) {
      lastHeardSecs = DateTime.now().difference(node.lastHeard!).inSeconds;
    }

    // Calculate reachability score
    final result = calculateReachabilityScore(
      obsData,
      lastHeardFromMeshNode: lastHeardSecs,
      rssiFromMeshNode: node.rssi?.toDouble(),
      snrFromMeshNode: node.snr?.toDouble(),
    );

    results.add(
      NodeWithReachability(
        node: node,
        reachability: result,
        observationData: obsData,
      ),
    );
  }

  // Sort by score descending (most reachable first)
  results.sort((a, b) => b.sortKey.compareTo(a.sortKey));

  return results;
});

/// Provider for nodes filtered and grouped by reachability likelihood.
final nodesByReachabilityProvider = Provider<NodesByReachability>((ref) {
  final nodes = ref.watch(nodesWithReachabilityProvider);

  final high = <NodeWithReachability>[];
  final medium = <NodeWithReachability>[];
  final low = <NodeWithReachability>[];

  for (final node in nodes) {
    switch (node.reachability.likelihood) {
      case ReachLikelihood.high:
        high.add(node);
      case ReachLikelihood.medium:
        medium.add(node);
      case ReachLikelihood.low:
        low.add(node);
    }
  }

  return NodesByReachability(
    high: high,
    medium: medium,
    low: low,
    total: nodes.length,
  );
});

/// Container for nodes grouped by reachability likelihood.
class NodesByReachability {
  final List<NodeWithReachability> high;
  final List<NodeWithReachability> medium;
  final List<NodeWithReachability> low;
  final int total;

  const NodesByReachability({
    required this.high,
    required this.medium,
    required this.low,
    required this.total,
  });

  /// Check if there are any nodes to display.
  bool get isEmpty => total == 0;

  /// Check if there are nodes to display.
  bool get isNotEmpty => total > 0;
}
