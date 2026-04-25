// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Aggregate observability counters for port-76 (`RETICULUM_TUNNEL_APP`)
/// fragment traffic.
///
/// All numbers are derived from the live fragment stream. Updates are
/// emitted as new immutable [ReticulumStats] snapshots.
class ReticulumStats {
  const ReticulumStats({
    this.totalFragments = 0,
    this.lastSeenMs,
    this.topSources = const [],
    this.avgFragmentSize = 0,
    this.fragmentsPerSecond = 0,
    this.distinctSourceCount = 0,
  });

  static const empty = ReticulumStats();

  /// Lifetime fragment count since process start.
  final int totalFragments;

  /// Wall-clock timestamp of the most recent fragment, or null if none yet.
  final int? lastSeenMs;

  /// Top sources ordered by recency (most recent first). Bounded to
  /// [ReticulumStats.topSourcesLimit] entries.
  final List<ReticulumStatsSource> topSources;

  /// Running mean of payload length across all observed fragments.
  final double avgFragmentSize;

  /// Fragments per second across the most recent 60 s rolling window.
  final double fragmentsPerSecond;

  /// Distinct source nodeIds seen in the lifetime of this process.
  final int distinctSourceCount;

  /// Maximum number of entries retained in [topSources] (LRU by recency).
  static const int topSourcesLimit = 10;

  /// Width of the rolling-window for [fragmentsPerSecond], in seconds.
  static const int rollingWindowSeconds = 60;

  ReticulumStats copyWith({
    int? totalFragments,
    int? lastSeenMs,
    List<ReticulumStatsSource>? topSources,
    double? avgFragmentSize,
    double? fragmentsPerSecond,
    int? distinctSourceCount,
  }) {
    return ReticulumStats(
      totalFragments: totalFragments ?? this.totalFragments,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      topSources: topSources ?? this.topSources,
      avgFragmentSize: avgFragmentSize ?? this.avgFragmentSize,
      fragmentsPerSecond: fragmentsPerSecond ?? this.fragmentsPerSecond,
      distinctSourceCount: distinctSourceCount ?? this.distinctSourceCount,
    );
  }
}

class ReticulumStatsSource {
  const ReticulumStatsSource({
    required this.nodeId,
    required this.fragmentCount,
    required this.lastSeenMs,
  });

  final int nodeId;
  final int fragmentCount;
  final int lastSeenMs;

  ReticulumStatsSource copyWith({int? fragmentCount, int? lastSeenMs}) {
    return ReticulumStatsSource(
      nodeId: nodeId,
      fragmentCount: fragmentCount ?? this.fragmentCount,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReticulumStatsSource &&
          nodeId == other.nodeId &&
          fragmentCount == other.fragmentCount &&
          lastSeenMs == other.lastSeenMs;

  @override
  int get hashCode => Object.hash(nodeId, fragmentCount, lastSeenMs);
}
