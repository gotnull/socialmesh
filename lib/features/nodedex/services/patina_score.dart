// SPDX-License-Identifier: GPL-3.0-or-later

// Patina Score — deterministic digital history score.
//
// Patina is NOT fake damage or cosmetic aging. It is a numerical
// measure of how much observable history a node has accumulated
// in the user's field journal. A score of 0 means "just discovered,
// almost nothing known." A score of 100 means "deeply documented,
// rich history across time, space, and relationships."
//
// The score is computed from six orthogonal axes, each contributing
// a weighted fraction of the total. All inputs come from NodeDexEntry
// fields that already exist. No randomness, no side effects.
//
// Axes:
//   1. Tenure       (20%) — how long the node has been known
//   2. Encounters   (20%) — how many times seen
//   3. Reach        (15%) — geographic spread (regions + positions)
//   4. Signal depth (15%) — quality of signal records collected
//   5. Social       (15%) — co-seen relationships and messages
//   6. Recency      (15%) — how recently active (rewards liveness)
//
// Each axis uses a logarithmic or asymptotic curve so that early
// gains are meaningful but diminishing returns prevent runaway scores.
// A node seen 3 times over 2 days with 1 region will score ~15-25.
// A node seen 50 times over 30 days across 4 regions will score ~60-75.

import 'dart:math' as math;

import '../models/nodedex_entry.dart';

/// Result of a patina score computation.
///
/// Contains the overall score plus per-axis breakdowns so the UI
/// can optionally show which dimensions contribute most.
class PatinaResult {
  /// Overall patina score, 0 to 100 inclusive.
  final int score;

  /// Per-axis scores, each 0.0 to 1.0.
  final double tenure;
  final double encounters;
  final double reach;
  final double signalDepth;
  final double social;
  final double recency;

  /// A short label derived from the score range.
  ///
  /// Used as the "stamp" text in the UI (e.g., "Ink: 62").
  final String stampLabel;

  const PatinaResult({
    required this.score,
    required this.tenure,
    required this.encounters,
    required this.reach,
    required this.signalDepth,
    required this.social,
    required this.recency,
    required this.stampLabel,
  });

  @override
  String toString() => 'PatinaResult($stampLabel: $score)';
}

/// Pure-function engine that computes a patina score from node history.
///
/// All methods are static. No state, no side effects, no async.
/// The same NodeDexEntry always produces the same PatinaResult.
class PatinaScore {
  PatinaScore._();

  // ---------------------------------------------------------------------------
  // Axis weights — must sum to 1.0
  // ---------------------------------------------------------------------------

  static const double _wTenure = 0.20;
  static const double _wEncounters = 0.20;
  static const double _wReach = 0.15;
  static const double _wSignalDepth = 0.15;
  static const double _wSocial = 0.15;
  static const double _wRecency = 0.15;

  // ---------------------------------------------------------------------------
  // Saturation constants — the input value at which the axis reaches ~90%
  // ---------------------------------------------------------------------------

  /// Days known before tenure axis saturates.
  static const double _tenureSaturationDays = 90.0;

  /// Encounter count before encounters axis saturates.
  static const double _encounterSaturation = 60.0;

  /// Number of distinct regions before reach saturates.
  static const double _regionSaturation = 6.0;

  /// Number of distinct positions before reach saturates.
  static const double _positionSaturation = 10.0;

  /// Co-seen node count before social axis saturates.
  static const double _coSeenSaturation = 20.0;

  /// Message count before social axis saturates.
  static const double _messageSaturation = 30.0;

  // ---------------------------------------------------------------------------
  // Stamp labels by score range
  // ---------------------------------------------------------------------------

  static const List<(int, String)> _stampRanges = [
    (0, 'Trace'),
    (10, 'Faint'),
    (25, 'Noted'),
    (40, 'Logged'),
    (55, 'Inked'),
    (70, 'Etched'),
    (85, 'Archival'),
    (95, 'Canonical'),
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Compute the patina score for a node.
  ///
  /// The result is deterministic: the same [entry] always produces
  /// the same score, given the same wall-clock time (which affects
  /// tenure and recency). For testing, use [computeAt] to pin the
  /// reference time.
  static PatinaResult compute(NodeDexEntry entry) {
    return computeAt(entry, DateTime.now());
  }

  /// Compute the patina score at a specific reference time.
  ///
  /// Useful for deterministic testing. In production, use [compute].
  static PatinaResult computeAt(NodeDexEntry entry, DateTime now) {
    final tenure = _scoreTenure(entry, now);
    final encounters = _scoreEncounters(entry);
    final reach = _scoreReach(entry);
    final signalDepth = _scoreSignalDepth(entry);
    final social = _scoreSocial(entry);
    final recency = _scoreRecency(entry, now);

    final raw =
        tenure * _wTenure +
        encounters * _wEncounters +
        reach * _wReach +
        signalDepth * _wSignalDepth +
        social * _wSocial +
        recency * _wRecency;

    final score = (raw * 100).round().clamp(0, 100);
    final label = _stampLabelFor(score);

    return PatinaResult(
      score: score,
      tenure: tenure,
      encounters: encounters,
      reach: reach,
      signalDepth: signalDepth,
      social: social,
      recency: recency,
      stampLabel: label,
    );
  }

  // ---------------------------------------------------------------------------
  // Axis scoring functions — each returns 0.0 to 1.0
  // ---------------------------------------------------------------------------

  /// Tenure: how long this node has been known.
  ///
  /// Uses an asymptotic curve: score = 1 - e^(-k * days).
  /// Reaches ~63% at 30 days, ~86% at 60 days, ~95% at 90 days.
  static double _scoreTenure(NodeDexEntry entry, DateTime now) {
    final ageDays = now.difference(entry.firstSeen).inHours / 24.0;
    if (ageDays <= 0) return 0.0;
    // k chosen so that at _tenureSaturationDays we reach ~95%
    const k = 3.0; // 1 - e^(-3) ≈ 0.95
    return (1.0 - math.exp(-k * ageDays / _tenureSaturationDays)).clamp(
      0.0,
      1.0,
    );
  }

  /// Encounters: how many times this node has been observed.
  ///
  /// Logarithmic curve: fast early gains, slow later.
  static double _scoreEncounters(NodeDexEntry entry) {
    if (entry.encounterCount <= 0) return 0.0;
    // ln(1 + count) / ln(1 + saturation)
    return (math.log(1.0 + entry.encounterCount) /
            math.log(1.0 + _encounterSaturation))
        .clamp(0.0, 1.0);
  }

  /// Reach: geographic spread — regions and distinct positions.
  ///
  /// Blends region count (60%) and position count (40%).
  static double _scoreReach(NodeDexEntry entry) {
    final regionScore = entry.regionCount > 0
        ? (math.log(1.0 + entry.regionCount) /
                  math.log(1.0 + _regionSaturation))
              .clamp(0.0, 1.0)
        : 0.0;

    final positionScore = entry.distinctPositionCount > 0
        ? (math.log(1.0 + entry.distinctPositionCount) /
                  math.log(1.0 + _positionSaturation))
              .clamp(0.0, 1.0)
        : 0.0;

    return (regionScore * 0.6 + positionScore * 0.4).clamp(0.0, 1.0);
  }

  /// Signal depth: quality of collected signal records.
  ///
  /// Rewards having both SNR and RSSI data, plus encounter records
  /// that contain signal measurements.
  static double _scoreSignalDepth(NodeDexEntry entry) {
    double score = 0.0;

    // Having best SNR recorded
    if (entry.bestSnr != null) score += 0.3;

    // Having best RSSI recorded
    if (entry.bestRssi != null) score += 0.3;

    // Encounter records with signal data
    if (entry.encounters.isNotEmpty) {
      int withSignal = 0;
      for (final e in entry.encounters) {
        if (e.snr != null || e.rssi != null) withSignal++;
      }
      final signalRatio = withSignal / entry.encounters.length;
      score += 0.4 * signalRatio;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Social: co-seen relationships and message activity.
  ///
  /// Blends co-seen node count (60%) and message count (40%).
  static double _scoreSocial(NodeDexEntry entry) {
    final coSeenScore = entry.coSeenCount > 0
        ? (math.log(1.0 + entry.coSeenCount) /
                  math.log(1.0 + _coSeenSaturation))
              .clamp(0.0, 1.0)
        : 0.0;

    final messageScore = entry.messageCount > 0
        ? (math.log(1.0 + entry.messageCount) /
                  math.log(1.0 + _messageSaturation))
              .clamp(0.0, 1.0)
        : 0.0;

    return (coSeenScore * 0.6 + messageScore * 0.4).clamp(0.0, 1.0);
  }

  /// Recency: how recently the node was active.
  ///
  /// Decays exponentially from last seen time. A node seen within
  /// the last hour scores 1.0. After 7 days of silence, score drops
  /// to near zero.
  static double _scoreRecency(NodeDexEntry entry, DateTime now) {
    final hoursSinceLastSeen = now.difference(entry.lastSeen).inMinutes / 60.0;
    if (hoursSinceLastSeen <= 0) return 1.0;

    // Decay half-life of ~24 hours: after 1 day ≈ 0.5, after 3 days ≈ 0.12
    const halfLifeHours = 24.0;
    const decayRate = 0.693147 / halfLifeHours; // ln(2) / half-life
    return math.exp(-decayRate * hoursSinceLastSeen).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Map a numeric score to a stamp label.
  static String _stampLabelFor(int score) {
    String label = _stampRanges.first.$2;
    for (final (threshold, name) in _stampRanges) {
      if (score >= threshold) {
        label = name;
      } else {
        break;
      }
    }
    return label;
  }
}
