// SPDX-License-Identifier: GPL-3.0-or-later

// Trait Engine — passive personality trait inference from real metrics.
//
// Traits are never user-editable. They are always derived from
// observable data: encounter patterns, position history, uptime,
// role, and activity frequency. The engine runs pure functions
// that take a NodeDexEntry and optional MeshNode data to produce
// a NodeTrait classification.
//
// Trait hierarchy (evaluated in priority order):
// 1. Relay — role is ROUTER or ROUTER_CLIENT with high throughput
// 2. Wanderer — seen across multiple distinct positions or regions
// 3. Sentinel — fixed position, long-lived, high encounter count
// 4. Beacon — always active, very frequent encounters
// 5. Ghost — rarely seen relative to age
// 6. Courier — high message volume relative to encounters
// 7. Anchor — persistent hub with many co-seen connections
// 8. Drifter — irregular timing, unpredictable appearance pattern
// 9. Unknown — insufficient data to classify
//
// Each trait has a confidence score (0.0 to 1.0) so the UI can
// optionally show how strongly a node matches its classification.
//
// The engine provides two APIs:
// - infer() — returns a single primary + optional secondary (legacy)
// - inferAll() — returns all scored traits with evidence lines

import '../models/nodedex_entry.dart';

/// A single piece of evidence supporting a trait score.
///
/// Evidence lines are human-readable explanations of why a trait
/// scored the way it did. They read like field journal observations.
class TraitEvidence {
  /// Short human-readable reason (e.g., "Seen across 4 regions").
  final String observation;

  /// How much this evidence contributed to the score (0.0 to 1.0).
  final double weight;

  const TraitEvidence({required this.observation, required this.weight});

  @override
  String toString() =>
      'TraitEvidence($observation, +${weight.toStringAsFixed(2)})';
}

/// A single trait with its score and supporting evidence.
///
/// Used by [TraitEngine.inferAll] to return the full ranked list
/// of traits with explanations.
class ScoredTrait {
  /// The trait classification.
  final NodeTrait trait;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Evidence lines explaining why this score was assigned.
  final List<TraitEvidence> evidence;

  const ScoredTrait({
    required this.trait,
    required this.confidence,
    this.evidence = const [],
  });

  @override
  String toString() =>
      'ScoredTrait(${trait.displayLabel} @ '
      '${(confidence * 100).toStringAsFixed(0)}%, '
      '${evidence.length} evidence)';
}

/// Result of trait inference for a single node.
///
/// Contains the primary trait, its confidence, and an optional
/// secondary trait if the node exhibits mixed behavior.
class TraitResult {
  /// The primary inferred trait.
  final NodeTrait primary;

  /// Confidence in the primary trait (0.0 to 1.0).
  final double confidence;

  /// Optional secondary trait if the node shows mixed signals.
  /// Only set when a secondary trait scores above 0.5.
  final NodeTrait? secondary;

  /// Confidence in the secondary trait, if present.
  final double? secondaryConfidence;

  const TraitResult({
    required this.primary,
    required this.confidence,
    this.secondary,
    this.secondaryConfidence,
  });

  @override
  String toString() =>
      'TraitResult(${primary.displayLabel} @ '
      '${(confidence * 100).toStringAsFixed(0)}%'
      '${secondary != null ? ', secondary: ${secondary!.displayLabel}' : ''})';
}

/// Pure-function engine that infers personality traits from node data.
///
/// The engine takes a NodeDexEntry (encounter history) and optional
/// live metrics (role, uptime, channel utilization) to produce a
/// trait classification. All inputs are read-only. No side effects.
class TraitEngine {
  TraitEngine._();

  /// Minimum encounter count before trait inference is meaningful.
  static const int _minEncountersForTrait = 3;

  /// Minimum age in hours before trait inference activates.
  static const int _minAgeHoursForTrait = 1;

  /// Encounter rate threshold (encounters per day) for Beacon trait.
  static const double _beaconEncounterRateThreshold = 8.0;

  /// Encounter rate threshold (encounters per day) below which Ghost applies.
  static const double _ghostEncounterRateThreshold = 0.3;

  /// Minimum distinct positions to qualify as Wanderer.
  static const int _wandererMinPositions = 3;

  /// Minimum regions to qualify as Wanderer via region diversity.
  static const int _wandererMinRegions = 2;

  /// Minimum encounter count to qualify as Sentinel.
  static const int _sentinelMinEncounters = 10;

  /// Minimum age in days for Sentinel consideration.
  static const int _sentinelMinAgeDays = 3;

  /// Roles that indicate relay behavior.
  static const Set<String> _relayRoles = {
    'ROUTER',
    'ROUTER_CLIENT',
    'REPEATER',
    'ROUTER_LATE',
  };

  /// Infer the trait for a node.
  ///
  /// [entry] — the NodeDex encounter history for this node.
  /// [role] — the node's configured role (from MeshNode.role), if known.
  /// [uptimeSeconds] — the node's reported uptime, if known.
  /// [channelUtilization] — the node's channel utilization %, if known.
  /// [airUtilTx] — the node's airtime TX utilization %, if known.
  ///
  /// Returns a TraitResult with the primary trait and confidence.
  static TraitResult infer({
    required NodeDexEntry entry,
    String? role,
    int? uptimeSeconds,
    double? channelUtilization,
    double? airUtilTx,
  }) {
    // Not enough data — return Unknown.
    if (!_hasEnoughData(entry)) {
      return const TraitResult(primary: NodeTrait.unknown, confidence: 1.0);
    }

    // Score each trait independently.
    final scores = <NodeTrait, double>{
      NodeTrait.relay: _scoreRelay(entry, role, channelUtilization, airUtilTx),
      NodeTrait.wanderer: _scoreWanderer(entry),
      NodeTrait.sentinel: _scoreSentinel(entry, uptimeSeconds),
      NodeTrait.beacon: _scoreBeacon(entry),
      NodeTrait.ghost: _scoreGhost(entry),
      NodeTrait.courier: _scoreCourier(entry),
      NodeTrait.anchor: _scoreAnchor(entry),
      NodeTrait.drifter: _scoreDrifter(entry),
    };

    // Find the highest scoring trait.
    NodeTrait bestTrait = NodeTrait.unknown;
    double bestScore = 0.0;
    NodeTrait? secondTrait;
    double? secondScore;

    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        // Demote current best to second.
        if (bestScore > 0.5) {
          secondTrait = bestTrait;
          secondScore = bestScore;
        }
        bestTrait = entry.key;
        bestScore = entry.value;
      } else if (entry.value > 0.5 &&
          (secondScore == null || entry.value > secondScore)) {
        secondTrait = entry.key;
        secondScore = entry.value;
      }
    }

    // If no trait scored above threshold, fall back to Unknown.
    if (bestScore < 0.3) {
      return const TraitResult(primary: NodeTrait.unknown, confidence: 1.0);
    }

    return TraitResult(
      primary: bestTrait,
      confidence: bestScore.clamp(0.0, 1.0),
      secondary: secondTrait != NodeTrait.unknown ? secondTrait : null,
      secondaryConfidence: secondScore,
    );
  }

  /// Infer ALL traits for a node, ranked by confidence with evidence.
  ///
  /// Returns 3 to 7 [ScoredTrait] entries, sorted by descending
  /// confidence. Only traits scoring above [minConfidence] are
  /// included (default: 0.1). Unknown is never included.
  ///
  /// Each ScoredTrait carries evidence lines explaining why the
  /// score was assigned. This powers the "why this trait" UI in
  /// the field journal detail view.
  static List<ScoredTrait> inferAll({
    required NodeDexEntry entry,
    String? role,
    int? uptimeSeconds,
    double? channelUtilization,
    double? airUtilTx,
    double minConfidence = 0.1,
  }) {
    if (!_hasEnoughData(entry)) {
      return const [
        ScoredTrait(
          trait: NodeTrait.unknown,
          confidence: 1.0,
          evidence: [
            TraitEvidence(
              observation: 'Insufficient data to classify',
              weight: 1.0,
            ),
          ],
        ),
      ];
    }

    final scored = <ScoredTrait>[
      _scoreRelayWithEvidence(entry, role, channelUtilization, airUtilTx),
      _scoreWandererWithEvidence(entry),
      _scoreSentinelWithEvidence(entry, uptimeSeconds),
      _scoreBeaconWithEvidence(entry),
      _scoreGhostWithEvidence(entry),
      _scoreCourierWithEvidence(entry),
      _scoreAnchorWithEvidence(entry),
      _scoreDrifterWithEvidence(entry),
    ];

    // Filter by minimum confidence and sort descending.
    final filtered = scored.where((s) => s.confidence >= minConfidence).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    // Return at least 3, at most 7.
    if (filtered.length < 3) {
      // Pad with lowest-scoring traits from the full list.
      final remaining = scored.where((s) => !filtered.contains(s)).toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      while (filtered.length < 3 && remaining.isNotEmpty) {
        filtered.add(remaining.removeAt(0));
      }
    }

    return filtered.take(7).toList();
  }

  /// Quick trait inference that returns just the primary trait.
  ///
  /// Use this when you only need the trait enum without confidence
  /// details (e.g., for list display).
  static NodeTrait inferPrimary({
    required NodeDexEntry entry,
    String? role,
    int? uptimeSeconds,
    double? channelUtilization,
    double? airUtilTx,
  }) {
    return infer(
      entry: entry,
      role: role,
      uptimeSeconds: uptimeSeconds,
      channelUtilization: channelUtilization,
      airUtilTx: airUtilTx,
    ).primary;
  }

  // ---------------------------------------------------------------------------
  // Prerequisite check
  // ---------------------------------------------------------------------------

  static bool _hasEnoughData(NodeDexEntry entry) {
    if (entry.encounterCount < _minEncountersForTrait) return false;
    if (entry.age.inHours < _minAgeHoursForTrait) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Individual trait scoring functions
  // ---------------------------------------------------------------------------

  /// Score Relay trait.
  ///
  /// High score when the node has a router/repeater role and shows
  /// signs of active forwarding (channel utilization, airtime TX).
  static double _scoreRelay(
    NodeDexEntry entry,
    String? role,
    double? channelUtilization,
    double? airUtilTx,
  ) {
    double score = 0.0;

    // Role is the strongest signal for relay behavior.
    if (role != null && _relayRoles.contains(role.toUpperCase())) {
      score += 0.6;
    }

    // Channel utilization above 10% suggests active forwarding.
    if (channelUtilization != null && channelUtilization > 10.0) {
      score += 0.2 * (channelUtilization / 50.0).clamp(0.0, 1.0);
    }

    // Airtime TX above 5% suggests active transmission.
    if (airUtilTx != null && airUtilTx > 5.0) {
      score += 0.2 * (airUtilTx / 30.0).clamp(0.0, 1.0);
    }

    // High encounter count boosts relay score slightly — relays are
    // seen frequently because they are always on.
    if (entry.encounterCount > 20) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Wanderer trait.
  ///
  /// High score when the node has been seen across multiple distinct
  /// positions or regions, indicating mobility.
  static double _scoreWanderer(NodeDexEntry entry) {
    double score = 0.0;

    // Multiple distinct positions is the primary Wanderer signal.
    final positionCount = entry.distinctPositionCount;
    if (positionCount >= _wandererMinPositions) {
      score += 0.5 * (positionCount / 10.0).clamp(0.0, 1.0);
    }

    // Region diversity is a strong Wanderer signal.
    if (entry.regionCount >= _wandererMinRegions) {
      score += 0.4 * (entry.regionCount / 5.0).clamp(0.0, 1.0);
    }

    // If the max distance is very high, that supports Wanderer.
    if (entry.maxDistanceSeen != null && entry.maxDistanceSeen! > 5000) {
      score += 0.1 * (entry.maxDistanceSeen! / 50000.0).clamp(0.0, 1.0);
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Sentinel trait.
  ///
  /// High score when the node is in a fixed position, has been around
  /// for a long time, and is seen reliably.
  static double _scoreSentinel(NodeDexEntry entry, int? uptimeSeconds) {
    double score = 0.0;

    // Low position diversity suggests fixed installation.
    final positionCount = entry.distinctPositionCount;
    if (positionCount <= 1) {
      score += 0.3;
    }

    // Long age suggests permanence.
    if (entry.age.inDays >= _sentinelMinAgeDays) {
      score += 0.3 * (entry.age.inDays / 30.0).clamp(0.0, 1.0);
    }

    // High encounter count relative to age suggests reliability.
    if (entry.encounterCount >= _sentinelMinEncounters) {
      final encounterRate = _encounterRatePerDay(entry);
      if (encounterRate >= 1.0) {
        score += 0.2 * (encounterRate / 5.0).clamp(0.0, 1.0);
      }
    }

    // High uptime confirms fixed infrastructure.
    if (uptimeSeconds != null && uptimeSeconds > 86400) {
      // More than 1 day uptime
      score +=
          0.2 *
          (uptimeSeconds / (7 * 86400.0)).clamp(0.0, 1.0); // Scale to 7 days
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Beacon trait.
  ///
  /// High score when the node is encountered very frequently,
  /// suggesting it is always broadcasting.
  static double _scoreBeacon(NodeDexEntry entry) {
    double score = 0.0;

    final encounterRate = _encounterRatePerDay(entry);

    // Very high encounter rate is the primary Beacon signal.
    if (encounterRate >= _beaconEncounterRateThreshold) {
      score += 0.7 * (encounterRate / 20.0).clamp(0.0, 1.0);
    } else if (encounterRate >= _beaconEncounterRateThreshold / 2) {
      score +=
          0.3 * (encounterRate / _beaconEncounterRateThreshold).clamp(0.0, 1.0);
    }

    // Recently seen (within last hour) slightly boosts Beacon.
    if (entry.timeSinceLastSeen.inMinutes < 60) {
      score += 0.15;
    }

    // Many total encounters confirms beacon behavior.
    if (entry.encounterCount > 30) {
      score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Ghost trait.
  ///
  /// High score when the node is rarely seen relative to how long
  /// it has been known, suggesting intermittent or erratic presence.
  static double _scoreGhost(NodeDexEntry entry) {
    double score = 0.0;

    // Must have been known for at least a day to be ghostly.
    if (entry.age.inDays < 1) return 0.0;

    final encounterRate = _encounterRatePerDay(entry);

    // Very low encounter rate is the primary Ghost signal.
    if (encounterRate <= _ghostEncounterRateThreshold) {
      score +=
          0.6 *
          (1.0 - (encounterRate / _ghostEncounterRateThreshold)).clamp(
            0.0,
            1.0,
          );
    }

    // Long time since last seen boosts Ghost.
    if (entry.timeSinceLastSeen.inHours > 24) {
      score +=
          0.2 * (entry.timeSinceLastSeen.inHours / (7 * 24.0)).clamp(0.0, 1.0);
    }

    // Low encounter count relative to age.
    if (entry.age.inDays > 7 && entry.encounterCount < 5) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Courier trait.
  ///
  /// High score when the node has a high message-to-encounter ratio,
  /// suggesting it primarily carries data across the mesh.
  static double _scoreCourier(NodeDexEntry entry) {
    double score = 0.0;

    if (entry.encounterCount < _minEncountersForTrait) return 0.0;

    // High message-to-encounter ratio is the primary Courier signal.
    final messageRatio = entry.messageCount / entry.encounterCount.toDouble();
    if (messageRatio >= 2.0) {
      score += 0.5 * (messageRatio / 10.0).clamp(0.0, 1.0);
    } else if (messageRatio >= 0.5) {
      score += 0.2 * (messageRatio / 2.0).clamp(0.0, 1.0);
    }

    // High absolute message count supports Courier.
    if (entry.messageCount >= 10) {
      score += 0.3 * (entry.messageCount / 50.0).clamp(0.0, 1.0);
    }

    // Mobility + messages — a true courier moves AND carries data.
    if (entry.distinctPositionCount >= 2 && entry.messageCount >= 5) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Anchor trait.
  ///
  /// High score when the node is a persistent hub with many co-seen
  /// connections, acting as a social center of the mesh graph.
  static double _scoreAnchor(NodeDexEntry entry) {
    double score = 0.0;

    // High co-seen count is the primary Anchor signal.
    if (entry.coSeenCount >= 5) {
      score += 0.5 * (entry.coSeenCount / 20.0).clamp(0.0, 1.0);
    } else if (entry.coSeenCount >= 2) {
      score += 0.2 * (entry.coSeenCount / 5.0).clamp(0.0, 1.0);
    }

    // Long tenure supports Anchor — hubs are persistent.
    if (entry.age.inDays >= 7) {
      score += 0.2 * (entry.age.inDays / 30.0).clamp(0.0, 1.0);
    }

    // Low position diversity — anchors tend to stay put.
    if (entry.distinctPositionCount <= 1) {
      score += 0.15;
    }

    // High encounter count — anchors are reliably present.
    if (entry.encounterCount >= 15) {
      score += 0.15 * (entry.encounterCount / 40.0).clamp(0.0, 1.0);
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score Drifter trait.
  ///
  /// High score when the node appears irregularly — not ghostly
  /// (which implies rarity) but with unpredictable timing between
  /// encounters.
  static double _scoreDrifter(NodeDexEntry entry) {
    double score = 0.0;

    if (entry.encounters.length < 4) return 0.0;

    // Compute coefficient of variation of inter-encounter intervals.
    // High CV means irregular timing.
    final intervals = <double>[];
    for (int i = 1; i < entry.encounters.length; i++) {
      final gap = entry.encounters[i - 1].timestamp
          .difference(entry.encounters[i].timestamp)
          .inMinutes
          .abs()
          .toDouble();
      if (gap > 0) intervals.add(gap);
    }

    if (intervals.length >= 3) {
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      if (mean > 0) {
        double sumSqDiff = 0;
        for (final iv in intervals) {
          sumSqDiff += (iv - mean) * (iv - mean);
        }
        final stddev = _sqrt(sumSqDiff / intervals.length);
        final cv = stddev / mean; // coefficient of variation

        // CV > 1.0 means high irregularity.
        if (cv > 1.0) {
          score += 0.5 * (cv / 3.0).clamp(0.0, 1.0);
        } else if (cv > 0.5) {
          score += 0.2 * ((cv - 0.5) / 0.5).clamp(0.0, 1.0);
        }
      }
    }

    // Secondary signals only amplify when irregular timing is present.
    // A node with perfectly regular timing should never be a "drifter."
    if (score > 0) {
      // Moderate encounter rate — not a ghost, but not a beacon either.
      final encounterRate = _encounterRatePerDay(entry);
      if (encounterRate > _ghostEncounterRateThreshold &&
          encounterRate < _beaconEncounterRateThreshold) {
        score += 0.3;
      }

      // Some position diversity adds to drifter feel.
      if (entry.distinctPositionCount >= 2 &&
          entry.distinctPositionCount <= 5) {
        score += 0.2;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Evidence-producing variants (for inferAll)
  // ---------------------------------------------------------------------------

  static ScoredTrait _scoreRelayWithEvidence(
    NodeDexEntry entry,
    String? role,
    double? channelUtilization,
    double? airUtilTx,
  ) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    if (role != null && _relayRoles.contains(role.toUpperCase())) {
      final s = 0.6;
      score += s;
      evidence.add(
        TraitEvidence(observation: 'Role is ${role.toUpperCase()}', weight: s),
      );
    }

    if (channelUtilization != null && channelUtilization > 10.0) {
      final s = 0.2 * (channelUtilization / 50.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation:
              'Channel utilization ${channelUtilization.toStringAsFixed(0)}%',
          weight: s,
        ),
      );
    }

    if (airUtilTx != null && airUtilTx > 5.0) {
      final s = 0.2 * (airUtilTx / 30.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Airtime TX ${airUtilTx.toStringAsFixed(1)}%',
          weight: s,
        ),
      );
    }

    if (entry.encounterCount > 20) {
      score += 0.1;
      evidence.add(
        const TraitEvidence(
          observation: 'High encounter count (20+)',
          weight: 0.1,
        ),
      );
    }

    return ScoredTrait(
      trait: NodeTrait.relay,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreWandererWithEvidence(NodeDexEntry entry) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    final positionCount = entry.distinctPositionCount;
    if (positionCount >= _wandererMinPositions) {
      final s = 0.5 * (positionCount / 10.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Observed at $positionCount distinct positions',
          weight: s,
        ),
      );
    }

    if (entry.regionCount >= _wandererMinRegions) {
      final s = 0.4 * (entry.regionCount / 5.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Seen across ${entry.regionCount} regions',
          weight: s,
        ),
      );
    }

    if (entry.maxDistanceSeen != null && entry.maxDistanceSeen! > 5000) {
      final s = 0.1 * (entry.maxDistanceSeen! / 50000.0).clamp(0.0, 1.0);
      score += s;
      final km = (entry.maxDistanceSeen! / 1000).toStringAsFixed(1);
      evidence.add(TraitEvidence(observation: 'Max range ${km}km', weight: s));
    }

    return ScoredTrait(
      trait: NodeTrait.wanderer,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreSentinelWithEvidence(
    NodeDexEntry entry,
    int? uptimeSeconds,
  ) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    final positionCount = entry.distinctPositionCount;
    if (positionCount <= 1) {
      score += 0.3;
      evidence.add(
        const TraitEvidence(
          observation: 'Fixed position (single location)',
          weight: 0.3,
        ),
      );
    }

    if (entry.age.inDays >= _sentinelMinAgeDays) {
      final s = 0.3 * (entry.age.inDays / 30.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Known for ${entry.age.inDays} days',
          weight: s,
        ),
      );
    }

    if (entry.encounterCount >= _sentinelMinEncounters) {
      final encounterRate = _encounterRatePerDay(entry);
      if (encounterRate >= 1.0) {
        final s = 0.2 * (encounterRate / 5.0).clamp(0.0, 1.0);
        score += s;
        evidence.add(
          TraitEvidence(
            observation: '${encounterRate.toStringAsFixed(1)} encounters/day',
            weight: s,
          ),
        );
      }
    }

    if (uptimeSeconds != null && uptimeSeconds > 86400) {
      final days = (uptimeSeconds / 86400.0).toStringAsFixed(1);
      final s = 0.2 * (uptimeSeconds / (7 * 86400.0)).clamp(0.0, 1.0);
      score += s;
      evidence.add(TraitEvidence(observation: 'Uptime ${days}d', weight: s));
    }

    return ScoredTrait(
      trait: NodeTrait.sentinel,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreBeaconWithEvidence(NodeDexEntry entry) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    final encounterRate = _encounterRatePerDay(entry);

    if (encounterRate >= _beaconEncounterRateThreshold) {
      final s = 0.7 * (encounterRate / 20.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: '${encounterRate.toStringAsFixed(1)} encounters/day',
          weight: s,
        ),
      );
    } else if (encounterRate >= _beaconEncounterRateThreshold / 2) {
      final s =
          0.3 * (encounterRate / _beaconEncounterRateThreshold).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation:
              'Moderate encounter rate (${encounterRate.toStringAsFixed(1)}/day)',
          weight: s,
        ),
      );
    }

    if (entry.timeSinceLastSeen.inMinutes < 60) {
      score += 0.15;
      evidence.add(
        const TraitEvidence(
          observation: 'Active within the last hour',
          weight: 0.15,
        ),
      );
    }

    if (entry.encounterCount > 30) {
      score += 0.15;
      evidence.add(
        TraitEvidence(
          observation: '${entry.encounterCount} total encounters',
          weight: 0.15,
        ),
      );
    }

    return ScoredTrait(
      trait: NodeTrait.beacon,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreGhostWithEvidence(NodeDexEntry entry) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    if (entry.age.inDays < 1) {
      return const ScoredTrait(trait: NodeTrait.ghost, confidence: 0.0);
    }

    final encounterRate = _encounterRatePerDay(entry);

    if (encounterRate <= _ghostEncounterRateThreshold) {
      final s =
          0.6 *
          (1.0 - (encounterRate / _ghostEncounterRateThreshold)).clamp(
            0.0,
            1.0,
          );
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Encounter rate ${encounterRate.toStringAsFixed(2)}/day',
          weight: s,
        ),
      );
    }

    if (entry.timeSinceLastSeen.inHours > 24) {
      final s =
          0.2 * (entry.timeSinceLastSeen.inHours / (7 * 24.0)).clamp(0.0, 1.0);
      score += s;
      final days = (entry.timeSinceLastSeen.inHours / 24.0).toStringAsFixed(1);
      evidence.add(
        TraitEvidence(observation: 'Last seen ${days}d ago', weight: s),
      );
    }

    if (entry.age.inDays > 7 && entry.encounterCount < 5) {
      score += 0.2;
      evidence.add(
        TraitEvidence(
          observation:
              'Only ${entry.encounterCount} encounters over ${entry.age.inDays} days',
          weight: 0.2,
        ),
      );
    }

    return ScoredTrait(
      trait: NodeTrait.ghost,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreCourierWithEvidence(NodeDexEntry entry) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    if (entry.encounterCount < _minEncountersForTrait) {
      return const ScoredTrait(trait: NodeTrait.courier, confidence: 0.0);
    }

    final messageRatio = entry.messageCount / entry.encounterCount.toDouble();
    if (messageRatio >= 2.0) {
      final s = 0.5 * (messageRatio / 10.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation:
              '${messageRatio.toStringAsFixed(1)} messages per encounter',
          weight: s,
        ),
      );
    } else if (messageRatio >= 0.5) {
      final s = 0.2 * (messageRatio / 2.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation:
              '${messageRatio.toStringAsFixed(1)} messages per encounter',
          weight: s,
        ),
      );
    }

    if (entry.messageCount >= 10) {
      final s = 0.3 * (entry.messageCount / 50.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: '${entry.messageCount} messages exchanged',
          weight: s,
        ),
      );
    }

    if (entry.distinctPositionCount >= 2 && entry.messageCount >= 5) {
      score += 0.2;
      evidence.add(
        const TraitEvidence(
          observation: 'Mobile with active messaging',
          weight: 0.2,
        ),
      );
    }

    return ScoredTrait(
      trait: NodeTrait.courier,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreAnchorWithEvidence(NodeDexEntry entry) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    if (entry.coSeenCount >= 5) {
      final s = 0.5 * (entry.coSeenCount / 20.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Co-seen with ${entry.coSeenCount} nodes',
          weight: s,
        ),
      );
    } else if (entry.coSeenCount >= 2) {
      final s = 0.2 * (entry.coSeenCount / 5.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Co-seen with ${entry.coSeenCount} nodes',
          weight: s,
        ),
      );
    }

    if (entry.age.inDays >= 7) {
      final s = 0.2 * (entry.age.inDays / 30.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: 'Persistent presence (${entry.age.inDays} days)',
          weight: s,
        ),
      );
    }

    if (entry.distinctPositionCount <= 1) {
      score += 0.15;
      evidence.add(
        const TraitEvidence(observation: 'Fixed location', weight: 0.15),
      );
    }

    if (entry.encounterCount >= 15) {
      final s = 0.15 * (entry.encounterCount / 40.0).clamp(0.0, 1.0);
      score += s;
      evidence.add(
        TraitEvidence(
          observation: '${entry.encounterCount} encounters (reliable)',
          weight: s,
        ),
      );
    }

    return ScoredTrait(
      trait: NodeTrait.anchor,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  static ScoredTrait _scoreDrifterWithEvidence(NodeDexEntry entry) {
    final evidence = <TraitEvidence>[];
    double score = 0.0;

    if (entry.encounters.length < 4) {
      return const ScoredTrait(trait: NodeTrait.drifter, confidence: 0.0);
    }

    // Compute coefficient of variation of inter-encounter intervals.
    final intervals = <double>[];
    for (int i = 1; i < entry.encounters.length; i++) {
      final gap = entry.encounters[i - 1].timestamp
          .difference(entry.encounters[i].timestamp)
          .inMinutes
          .abs()
          .toDouble();
      if (gap > 0) intervals.add(gap);
    }

    if (intervals.length >= 3) {
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      if (mean > 0) {
        double sumSqDiff = 0;
        for (final iv in intervals) {
          sumSqDiff += (iv - mean) * (iv - mean);
        }
        final stddev = _sqrt(sumSqDiff / intervals.length);
        final cv = stddev / mean;

        if (cv > 1.0) {
          final s = 0.5 * (cv / 3.0).clamp(0.0, 1.0);
          score += s;
          evidence.add(
            TraitEvidence(
              observation: 'Irregular timing (CV ${cv.toStringAsFixed(1)})',
              weight: s,
            ),
          );
        } else if (cv > 0.5) {
          final s = 0.2 * ((cv - 0.5) / 0.5).clamp(0.0, 1.0);
          score += s;
          evidence.add(
            TraitEvidence(
              observation:
                  'Somewhat irregular timing (CV ${cv.toStringAsFixed(1)})',
              weight: s,
            ),
          );
        }
      }
    }

    // Secondary signals only amplify when irregular timing is present.
    // A node with perfectly regular timing should never be a "drifter."
    if (score > 0) {
      final encounterRate = _encounterRatePerDay(entry);
      if (encounterRate > _ghostEncounterRateThreshold &&
          encounterRate < _beaconEncounterRateThreshold) {
        score += 0.3;
        evidence.add(
          TraitEvidence(
            observation:
                'Moderate encounter rate (${encounterRate.toStringAsFixed(1)}/day)',
            weight: 0.3,
          ),
        );
      }

      if (entry.distinctPositionCount >= 2 &&
          entry.distinctPositionCount <= 5) {
        score += 0.2;
        evidence.add(
          TraitEvidence(
            observation: '${entry.distinctPositionCount} positions observed',
            weight: 0.2,
          ),
        );
      }
    }

    return ScoredTrait(
      trait: NodeTrait.drifter,
      confidence: score.clamp(0.0, 1.0),
      evidence: evidence,
    );
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Calculate the average encounter rate (encounters per day).
  static double _encounterRatePerDay(NodeDexEntry entry) {
    final ageDays = entry.age.inHours / 24.0;
    if (ageDays < 0.01) return entry.encounterCount.toDouble();
    return entry.encounterCount / ageDays;
  }

  /// Integer square root approximation (avoids dart:math import).
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
