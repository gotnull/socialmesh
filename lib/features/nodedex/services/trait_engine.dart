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
// 6. Unknown — insufficient data to classify
//
// Each trait has a confidence score (0.0 to 1.0) so the UI can
// optionally show how strongly a node matches its classification.

import '../models/nodedex_entry.dart';

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

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Calculate the average encounter rate (encounters per day).
  static double _encounterRatePerDay(NodeDexEntry entry) {
    final ageDays = entry.age.inHours / 24.0;
    if (ageDays < 0.01) return entry.encounterCount.toDouble();
    return entry.encounterCount / ageDays;
  }
}
