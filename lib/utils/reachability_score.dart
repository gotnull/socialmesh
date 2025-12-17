import 'dart:math' as math;

import '../models/reachability_models.dart';

// =============================================================================
// Opportunistic Mesh Reach Likelihood Model (v1) — BETA
// =============================================================================
//
// Author: Fulvio Cusumano (https://github.com/gotnull)
// Year: 2024–2025
//
// Description:
// A heuristic scoring model that estimates the likelihood of successfully
// reaching a node in an opportunistic mesh network based on observed RF
// metrics and packet history.
//
// Scope of Authorship:
// The author claims authorship of this specific formulation and weighting
// scheme. The model is a heuristic built from common RF and mesh networking
// concepts. No claim is made over underlying Meshtastic protocols, LoRa
// physical layer behaviour, or general networking theory.
//
// =============================================================================
// CORRECTION NOTICE
// =============================================================================
// The previous implementation used bucketed thresholds and heuristic weights.
// It did not match the agreed concrete scoring formula.
// This change corrects that mismatch.
//
// The previous implementation:
// - Used piecewise linear threshold buckets for freshness scoring
// - Applied manual "expired" penalties with secondary decay
// - Combined RSSI and SNR into a single "signal quality" factor
// - Used confidence factors based on sample counts
// - Had weight values (40%, 25%, 20%, 15%) not matching the specification
//
// This implementation now uses the exact concrete formula as specified.
// =============================================================================

/// This score represents likelihood, not reachability.
/// Meshtastic forwards packets opportunistically without routing.
/// A high score does not guarantee delivery.

/// Calculate a probabilistic reachability score for a node.
///
/// Implements the Opportunistic Mesh Reach Likelihood Model (v1).
///
/// Inputs:
///   t = seconds since last heard
///   h = minimum observed hop count, nullable
///   rssi = rolling average RSSI in dBm, nullable
///   snr = rolling average SNR in dB, nullable
///   directRatio = fraction of packets heard directly, nullable
///   ackRatio = first-hop DM ack success ratio, nullable
///
/// Normalisation:
///   freshness   = clamp(exp(−t / 1800), 0.05, 1.0)
///   hopScore    = h == null ? 0.4 : clamp(1 / (h + 1), 0.15, 1.0)
///   rssiScore   = rssi != null ? clamp((rssi + 120) / 60, 0.0, 1.0) : 0.4
///   snrScore    = snr != null ? clamp((snr + 10) / 20, 0.0, 1.0) : 0.5
///   directScore = directRatio != null ? clamp(directRatio, 0.0, 1.0) : 0.3
///   ackScore    = ackRatio != null ? clamp(ackRatio, 0.0, 1.0) : 0.5
///
/// Weighted combination:
///   rawScore = 0.30 * freshness
///            + 0.25 * hopScore
///            + 0.15 * directScore
///            + 0.15 * rssiScore
///            + 0.10 * snrScore
///            + 0.05 * ackScore
///
/// Final clamp:
///   reachScore = clamp(rawScore, 0.05, 0.95)
///
/// Returns a [ReachabilityResult] containing:
/// - score: A value from 0.05 to 0.95 indicating likelihood
/// - likelihood: Categorized as High (≥0.7), Medium (0.4-0.69), Low (<0.4)
/// - pathDepthLabel: Human-readable hop count description
/// - freshnessLabel: Human-readable time since last heard
ReachabilityResult calculateReachabilityScore(
  NodeReachabilityData? reachData, {
  int? lastHeardFromMeshNode,
  double? rssiFromMeshNode,
  double? snrFromMeshNode,
}) {
  // Handle case where we have no data at all
  if (reachData == null || !reachData.hasAnyData) {
    if (lastHeardFromMeshNode != null) {
      // Use MeshNode fallback data
      return _calculateWithFormula(
        t: lastHeardFromMeshNode,
        h: null,
        rssi: rssiFromMeshNode,
        snr: snrFromMeshNode,
        directRatio: null,
        ackRatio: null,
      );
    }
    return ReachabilityResult.noData();
  }

  // Extract inputs from reachability data, with MeshNode fallbacks
  final t = reachData.lastHeardSeconds ?? lastHeardFromMeshNode;
  final h = reachData.minimumObservedHopCount;
  final rssi = reachData.averageRssi ?? rssiFromMeshNode;
  final snr = reachData.averageSnr ?? snrFromMeshNode;
  final directRatio = reachData.directVsIndirectRatio;
  final ackRatio = reachData.dmAckSuccessRatio;

  return _calculateWithFormula(
    t: t,
    h: h,
    rssi: rssi,
    snr: snr,
    directRatio: directRatio,
    ackRatio: ackRatio,
  );
}

/// Implements the concrete scoring formula.
ReachabilityResult _calculateWithFormula({
  required int? t,
  required int? h,
  required double? rssi,
  required double? snr,
  required double? directRatio,
  required double? ackRatio,
}) {
  // Normalisation step
  final freshness = _calculateFreshness(t);
  final hopScore = _calculateHopScore(h);
  final rssiScore = _calculateRssiScore(rssi);
  final snrScore = _calculateSnrScore(snr);
  final directScore = _calculateDirectScore(directRatio);
  final ackScoreValue = _calculateAckScore(ackRatio);

  // Weighted combination (exact weights from specification)
  final rawScore =
      (0.30 * freshness) +
      (0.25 * hopScore) +
      (0.15 * directScore) +
      (0.15 * rssiScore) +
      (0.10 * snrScore) +
      (0.05 * ackScoreValue);

  // Final clamp
  final reachScore = rawScore.clamp(0.05, 0.95);

  final likelihood = _scoreToLikelihood(reachScore);
  final pathDepthLabel = _formatPathDepth(h);
  final freshnessLabel = _formatFreshness(t);

  return ReachabilityResult(
    score: reachScore,
    likelihood: likelihood,
    pathDepthLabel: pathDepthLabel,
    freshnessLabel: freshnessLabel,
    hasObservations: t != null,
  );
}

/// freshness = clamp(exp(−t / 1800), 0.05, 1.0)
double _calculateFreshness(int? t) {
  if (t == null) return 0.05;
  final expValue = math.exp(-t / 1800.0);
  return expValue.clamp(0.05, 1.0);
}

/// hopScore = h == null ? 0.4 : clamp(1 / (h + 1), 0.15, 1.0)
double _calculateHopScore(int? h) {
  if (h == null) return 0.4;
  final score = 1.0 / (h + 1);
  return score.clamp(0.15, 1.0);
}

/// rssiScore = rssi != null ? clamp((rssi + 120) / 60, 0.0, 1.0) : 0.4
double _calculateRssiScore(double? rssi) {
  if (rssi == null) return 0.4;
  final score = (rssi + 120) / 60;
  return score.clamp(0.0, 1.0);
}

/// snrScore = snr != null ? clamp((snr + 10) / 20, 0.0, 1.0) : 0.5
double _calculateSnrScore(double? snr) {
  if (snr == null) return 0.5;
  final score = (snr + 10) / 20;
  return score.clamp(0.0, 1.0);
}

/// directScore = directRatio != null ? clamp(directRatio, 0.0, 1.0) : 0.3
double _calculateDirectScore(double? directRatio) {
  if (directRatio == null) return 0.3;
  return directRatio.clamp(0.0, 1.0);
}

/// ackScore = ackRatio != null ? clamp(ackRatio, 0.0, 1.0) : 0.5
double _calculateAckScore(double? ackRatio) {
  if (ackRatio == null) return 0.5;
  return ackRatio.clamp(0.0, 1.0);
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
