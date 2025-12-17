import '../models/reachability_models.dart';

/// Reachability Scoring Function
///
/// A pure, platform-agnostic function to calculate a probabilistic reachability score.
///
/// ## Design Principles
/// 1. Observational only - uses passively collected data, no probing
/// 2. Honest scoring - never claims certainty (no 0.0 or 1.0 scores)
/// 3. Graceful degradation - works with partial data
/// 4. Transparent - clearly documented weight factors
///
/// ## Score Factors (weighted average)
/// - Freshness (40%): How recently the node was heard
/// - Hop Count (25%): Minimum observed path depth
/// - Signal Quality (20%): Combined RSSI/SNR metrics
/// - Observation Pattern (15%): Direct vs indirect packet ratio

/// Weight factors for score calculation.
/// These can be tuned based on empirical mesh behavior observations.
class ReachabilityWeights {
  /// Weight for freshness component (time since last heard)
  static const double freshness = 0.40;

  /// Weight for hop count component (path depth)
  static const double hopCount = 0.25;

  /// Weight for signal quality component (RSSI + SNR)
  static const double signalQuality = 0.20;

  /// Weight for observation pattern component (direct/indirect ratio)
  static const double observationPattern = 0.15;
}

/// Time thresholds for freshness scoring (in seconds).
class FreshnessThresholds {
  /// Excellent freshness: heard within 2 minutes
  static const int excellent = 120;

  /// Good freshness: heard within 15 minutes
  static const int good = 900;

  /// Fair freshness: heard within 1 hour
  static const int fair = 3600;

  /// Poor freshness: heard within 6 hours
  static const int poor = 21600;

  /// Stale: heard within 24 hours
  static const int stale = 86400;

  /// Expired: not heard for over 24 hours
  static const int expired = 86400;
}

/// RSSI thresholds for signal quality scoring (in dBm).
class RssiThresholds {
  /// Excellent signal: -60 dBm or better
  static const double excellent = -60;

  /// Good signal: -80 dBm or better
  static const double good = -80;

  /// Fair signal: -100 dBm or better
  static const double fair = -100;

  /// Poor signal: worse than -100 dBm
  static const double poor = -120;
}

/// SNR thresholds for signal quality scoring (in dB).
class SnrThresholds {
  /// Excellent: +10 dB or better
  static const double excellent = 10;

  /// Good: 0 dB or better
  static const double good = 0;

  /// Fair: -10 dB or better
  static const double fair = -10;

  /// Poor: worse than -10 dB
  static const double poor = -20;
}

/// Calculate a probabilistic reachability score for a node.
///
/// Returns a [ReachabilityResult] containing:
/// - score: A value from 0.0 to 1.0 (exclusive) indicating likelihood
/// - likelihood: Categorized as High (≥0.7), Medium (0.4-0.69), Low (<0.4)
/// - pathDepthLabel: Human-readable hop count description
/// - freshnessLabel: Human-readable time since last heard
///
/// ## Important Notes
/// - This is a PROBABILISTIC ESTIMATE, not a guarantee
/// - Score never reaches exactly 0.0 or 1.0
/// - Based entirely on passive observation data
/// - Lower scores mean delivery is less likely, not impossible
///
/// ## Scoring Factors
/// Each factor contributes a 0.0-1.0 sub-score, weighted:
/// - Freshness (40%): Exponential decay based on lastHeardSeconds
/// - Hop Count (25%): Lower hops = higher score
/// - Signal Quality (20%): RSSI and SNR combined
/// - Observation Pattern (15%): More direct observations = higher score
ReachabilityResult calculateReachabilityScore(
  NodeReachabilityData? reachData, {
  int? lastHeardFromMeshNode,
  double? rssiFromMeshNode,
  double? snrFromMeshNode,
}) {
  // Handle case where we have no reachability data
  if (reachData == null || !reachData.hasAnyData) {
    // Fall back to MeshNode data if available
    if (lastHeardFromMeshNode != null) {
      return _calculateFromMeshNodeData(
        lastHeardSeconds: lastHeardFromMeshNode,
        rssi: rssiFromMeshNode,
        snr: snrFromMeshNode,
      );
    }
    return ReachabilityResult.noData();
  }

  // Calculate individual component scores (0.0 to 1.0 each)
  final freshnessScore = _calculateFreshnessScore(
    reachData.lastHeardSeconds ?? lastHeardFromMeshNode,
  );
  final hopCountScore = _calculateHopCountScore(
    reachData.minimumObservedHopCount,
  );
  final signalScore = _calculateSignalQualityScore(
    reachData.averageRssi ?? rssiFromMeshNode,
    reachData.averageSnr ?? snrFromMeshNode,
  );
  final patternScore = _calculateObservationPatternScore(
    reachData.directVsIndirectRatio,
    reachData.directPacketCount + reachData.indirectPacketCount,
  );

  // Weighted average
  var rawScore =
      (freshnessScore * ReachabilityWeights.freshness) +
      (hopCountScore * ReachabilityWeights.hopCount) +
      (signalScore * ReachabilityWeights.signalQuality) +
      (patternScore * ReachabilityWeights.observationPattern);

  // Clamp to valid range and ensure we never hit exactly 0.0 or 1.0
  rawScore = rawScore.clamp(0.05, 0.95);

  // Special case: if data is fully expired (>24h), drop score significantly
  final lastHeard = reachData.lastHeardSeconds ?? lastHeardFromMeshNode;
  if (lastHeard != null && lastHeard > FreshnessThresholds.expired) {
    // Decay further for very stale data
    final hoursExpired = (lastHeard - FreshnessThresholds.expired) / 3600;
    rawScore = (rawScore * 0.5 / (1 + hoursExpired * 0.1)).clamp(0.01, 0.35);
  }

  final likelihood = _scoreToLikelihood(rawScore);
  final pathDepthLabel = _formatPathDepth(reachData.minimumObservedHopCount);
  final freshnessLabel = _formatFreshness(lastHeard);

  return ReachabilityResult(
    score: rawScore,
    likelihood: likelihood,
    pathDepthLabel: pathDepthLabel,
    freshnessLabel: freshnessLabel,
    hasObservations: true,
  );
}

/// Calculate score from just MeshNode data when no reachability data exists.
ReachabilityResult _calculateFromMeshNodeData({
  required int lastHeardSeconds,
  double? rssi,
  double? snr,
}) {
  final freshnessScore = _calculateFreshnessScore(lastHeardSeconds);
  final signalScore = _calculateSignalQualityScore(rssi, snr);

  // Without hop count or observation pattern, weight freshness higher
  var rawScore = (freshnessScore * 0.65) + (signalScore * 0.35);
  rawScore = rawScore.clamp(0.05, 0.85); // Cap lower since we have less data

  // Apply expiry decay
  if (lastHeardSeconds > FreshnessThresholds.expired) {
    final hoursExpired =
        (lastHeardSeconds - FreshnessThresholds.expired) / 3600;
    rawScore = (rawScore * 0.5 / (1 + hoursExpired * 0.1)).clamp(0.01, 0.35);
  }

  final likelihood = _scoreToLikelihood(rawScore);

  return ReachabilityResult(
    score: rawScore,
    likelihood: likelihood,
    pathDepthLabel: 'Unknown',
    freshnessLabel: _formatFreshness(lastHeardSeconds),
    hasObservations: true,
  );
}

/// Calculate freshness score based on time since last heard.
/// Uses exponential decay with configurable thresholds.
double _calculateFreshnessScore(int? lastHeardSeconds) {
  if (lastHeardSeconds == null) return 0.1;

  // Exponential decay curve
  if (lastHeardSeconds <= FreshnessThresholds.excellent) {
    // 0-2 minutes: score 0.9-1.0
    return 0.9 + (0.1 * (1 - lastHeardSeconds / FreshnessThresholds.excellent));
  } else if (lastHeardSeconds <= FreshnessThresholds.good) {
    // 2-15 minutes: score 0.7-0.9
    final progress =
        (lastHeardSeconds - FreshnessThresholds.excellent) /
        (FreshnessThresholds.good - FreshnessThresholds.excellent);
    return 0.9 - (0.2 * progress);
  } else if (lastHeardSeconds <= FreshnessThresholds.fair) {
    // 15 min - 1 hour: score 0.5-0.7
    final progress =
        (lastHeardSeconds - FreshnessThresholds.good) /
        (FreshnessThresholds.fair - FreshnessThresholds.good);
    return 0.7 - (0.2 * progress);
  } else if (lastHeardSeconds <= FreshnessThresholds.poor) {
    // 1-6 hours: score 0.3-0.5
    final progress =
        (lastHeardSeconds - FreshnessThresholds.fair) /
        (FreshnessThresholds.poor - FreshnessThresholds.fair);
    return 0.5 - (0.2 * progress);
  } else if (lastHeardSeconds <= FreshnessThresholds.stale) {
    // 6-24 hours: score 0.1-0.3
    final progress =
        (lastHeardSeconds - FreshnessThresholds.poor) /
        (FreshnessThresholds.stale - FreshnessThresholds.poor);
    return 0.3 - (0.2 * progress);
  } else {
    // >24 hours: very low score
    return 0.05;
  }
}

/// Calculate hop count score.
/// Lower hop counts indicate more reliable paths.
double _calculateHopCountScore(int? minHopCount) {
  if (minHopCount == null) return 0.4; // Unknown = neutral

  switch (minHopCount) {
    case 0:
      return 0.95; // Direct RF contact - best case
    case 1:
      return 0.8; // Single hop - very good
    case 2:
      return 0.65; // Two hops - good
    case 3:
      return 0.5; // Three hops - fair
    case 4:
      return 0.35; // Four hops - starting to get unreliable
    case 5:
      return 0.25; // Five hops - increasingly unreliable
    default:
      return 0.15; // 6+ hops - low reliability
  }
}

/// Calculate signal quality score from RSSI and SNR.
/// Uses the better of the two if both available, or the available one.
double _calculateSignalQualityScore(double? rssi, double? snr) {
  if (rssi == null && snr == null) return 0.4; // Unknown = neutral

  double rssiScore = 0.4;
  double snrScore = 0.4;

  // RSSI scoring
  if (rssi != null) {
    if (rssi >= RssiThresholds.excellent) {
      rssiScore = 0.95;
    } else if (rssi >= RssiThresholds.good) {
      final progress =
          (rssi - RssiThresholds.good) /
          (RssiThresholds.excellent - RssiThresholds.good);
      rssiScore = 0.7 + (0.25 * progress);
    } else if (rssi >= RssiThresholds.fair) {
      final progress =
          (rssi - RssiThresholds.fair) /
          (RssiThresholds.good - RssiThresholds.fair);
      rssiScore = 0.4 + (0.3 * progress);
    } else {
      final progress =
          ((rssi - RssiThresholds.poor) /
                  (RssiThresholds.fair - RssiThresholds.poor))
              .clamp(0.0, 1.0);
      rssiScore = 0.1 + (0.3 * progress);
    }
  }

  // SNR scoring
  if (snr != null) {
    if (snr >= SnrThresholds.excellent) {
      snrScore = 0.95;
    } else if (snr >= SnrThresholds.good) {
      final progress =
          (snr - SnrThresholds.good) /
          (SnrThresholds.excellent - SnrThresholds.good);
      snrScore = 0.7 + (0.25 * progress);
    } else if (snr >= SnrThresholds.fair) {
      final progress =
          (snr - SnrThresholds.fair) /
          (SnrThresholds.good - SnrThresholds.fair);
      snrScore = 0.4 + (0.3 * progress);
    } else {
      final progress =
          ((snr - SnrThresholds.poor) /
                  (SnrThresholds.fair - SnrThresholds.poor))
              .clamp(0.0, 1.0);
      snrScore = 0.1 + (0.3 * progress);
    }
  }

  // If both available, take weighted average favoring the higher score
  if (rssi != null && snr != null) {
    final maxScore = rssiScore > snrScore ? rssiScore : snrScore;
    final minScore = rssiScore < snrScore ? rssiScore : snrScore;
    return (maxScore * 0.7) + (minScore * 0.3);
  }

  return rssi != null ? rssiScore : snrScore;
}

/// Calculate observation pattern score.
/// More direct RF observations indicate a more reliable path.
double _calculateObservationPatternScore(
  double? directRatio,
  int totalPackets,
) {
  if (directRatio == null || totalPackets == 0) return 0.4; // Unknown = neutral

  // Confidence factor based on sample size
  // More observations = more confidence in the ratio
  final confidenceFactor = (totalPackets / 20.0).clamp(0.3, 1.0);

  // Score based on direct ratio
  final baseScore = 0.3 + (directRatio * 0.6);

  // Apply confidence factor
  return 0.4 + ((baseScore - 0.4) * confidenceFactor);
}

/// Convert raw score to discrete likelihood category.
ReachLikelihood _scoreToLikelihood(double score) {
  if (score >= 0.7) return ReachLikelihood.high;
  if (score >= 0.4) return ReachLikelihood.medium;
  return ReachLikelihood.low;
}

/// Format hop count into human-readable label.
String _formatPathDepth(int? hopCount) {
  if (hopCount == null) return 'Unknown';
  if (hopCount == 0) return 'Direct RF';
  if (hopCount == 1) return 'Seen via 1 hop';
  return 'Seen via $hopCount hops';
}

/// Format seconds into human-readable freshness label.
String _formatFreshness(int? seconds) {
  if (seconds == null) return 'Never';

  if (seconds < 60) {
    return '${seconds}s ago';
  } else if (seconds < 3600) {
    final minutes = seconds ~/ 60;
    return '${minutes}m ago';
  } else if (seconds < 86400) {
    final hours = seconds ~/ 3600;
    return '${hours}h ago';
  } else {
    final days = seconds ~/ 86400;
    return '${days}d ago';
  }
}

/// Extension to make testing easier
extension ReachabilityScoreTestHelpers on double {
  /// Convert a freshness score back to approximate seconds for validation
  int? toApproximateSeconds() {
    if (this >= 0.9) return 60;
    if (this >= 0.7) return 600;
    if (this >= 0.5) return 1800;
    if (this >= 0.3) return 10800;
    if (this >= 0.1) return 43200;
    return 100000;
  }
}
