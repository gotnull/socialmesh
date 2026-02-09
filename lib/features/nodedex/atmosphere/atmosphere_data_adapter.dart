// SPDX-License-Identifier: GPL-3.0-or-later

// Atmosphere Data Adapter — converts mesh metrics to effect intensities.
//
// This is the bridge between live mesh data and the atmospheric visual
// system. It reads from existing Riverpod providers (nodeDexStats,
// trait distributions, patina scores) and produces a single immutable
// snapshot of intensity values for each atmospheric effect.
//
// The adapter is a pure function layer — no state, no side effects,
// no subscriptions. Providers call [AtmosphereDataAdapter.compute]
// with current mesh metrics and receive an [AtmosphereIntensities]
// record that the overlay widgets consume directly.
//
// Mapping rules:
//   Rain intensity      ← f(totalNodes, totalEncounters)
//   Ember intensity     ← f(averagePatina, relayFraction)
//   Mist intensity      ← f(ghostFraction, unknownFraction)
//   Starlight intensity ← f(totalNodes) with ambient floor
//
// All mappings use asymptotic curves (logarithmic or exponential
// saturation) so that early mesh growth produces visible changes
// but mature networks do not peg every effect at maximum. The
// intensity range for each effect is clamped between a floor
// (minimum visible when enabled) and a ceiling (maximum even at
// extreme metric values).

import 'dart:math' as math;

import '../models/nodedex_entry.dart';
import 'atmosphere_config.dart';

/// Immutable snapshot of computed intensities for all atmosphere effects.
///
/// Each value is in the range 0.0–1.0, where 0.0 means the effect
/// should not be visible and 1.0 means maximum visual density.
/// These values are pre-clamped between the configured floor and
/// ceiling for each effect type.
///
/// The overlay widgets multiply these base intensities by the
/// context-specific multiplier (constellation = 1.0, detail = 0.25,
/// map = 0.3) before passing them to the particle layers.
class AtmosphereIntensities {
  /// Rain effect intensity (0.0–1.0).
  /// Driven by packet activity and node count.
  final double rain;

  /// Ember effect intensity (0.0–1.0).
  /// Driven by average patina scores and relay node fraction.
  final double ember;

  /// Mist effect intensity (0.0–1.0).
  /// Driven by fraction of sparse/unknown nodes.
  final double mist;

  /// Starlight effect intensity (0.0–1.0).
  /// Ambient baseline with mild node-count scaling.
  final double starlight;

  const AtmosphereIntensities({
    required this.rain,
    required this.ember,
    required this.mist,
    required this.starlight,
  });

  /// All effects at zero — used when the atmosphere system is disabled
  /// or when there is no mesh data.
  static const zero = AtmosphereIntensities(
    rain: 0.0,
    ember: 0.0,
    mist: 0.0,
    starlight: 0.0,
  );

  /// Whether any effect has non-zero intensity.
  bool get hasAnyEffect => rain > 0 || ember > 0 || mist > 0 || starlight > 0;

  /// Apply a context-specific multiplier to all intensities.
  ///
  /// Used to scale effects for different screens:
  ///   - Constellation: 1.0 (full effect)
  ///   - Node detail: 0.25 (very subtle)
  ///   - Map overlay: 0.3 (subtle, must not interfere with readability)
  AtmosphereIntensities scaled(double multiplier) {
    if (multiplier <= 0) return zero;
    if (multiplier >= 1.0) return this;
    return AtmosphereIntensities(
      rain: (rain * multiplier).clamp(0.0, 1.0),
      ember: (ember * multiplier).clamp(0.0, 1.0),
      mist: (mist * multiplier).clamp(0.0, 1.0),
      starlight: (starlight * multiplier).clamp(0.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AtmosphereIntensities) return false;
    return rain == other.rain &&
        ember == other.ember &&
        mist == other.mist &&
        starlight == other.starlight;
  }

  @override
  int get hashCode => Object.hash(rain, ember, mist, starlight);

  @override
  String toString() =>
      'AtmosphereIntensities(rain: ${rain.toStringAsFixed(2)}, '
      'ember: ${ember.toStringAsFixed(2)}, '
      'mist: ${mist.toStringAsFixed(2)}, '
      'starlight: ${starlight.toStringAsFixed(2)})';
}

/// Raw mesh metrics consumed by the adapter.
///
/// This is a thin data class that decouples the adapter from
/// specific provider types. The caller (typically a Riverpod
/// provider) collects these values from various sources and
/// passes them as a single bundle.
class MeshAtmosphereMetrics {
  /// Total number of discovered nodes in NodeDex.
  final int totalNodes;

  /// Total number of encounters across all nodes.
  final int totalEncounters;

  /// Number of nodes with the relay trait.
  final int relayNodeCount;

  /// Number of nodes with the ghost trait.
  final int ghostNodeCount;

  /// Number of nodes with the unknown trait.
  final int unknownNodeCount;

  /// Number of nodes with the beacon trait.
  final int beaconNodeCount;

  /// Average patina score across all nodes (0–100).
  /// Use 0.0 if no patina data is available.
  final double averagePatinaScore;

  /// Number of distinct regions observed.
  final int regionCount;

  const MeshAtmosphereMetrics({
    this.totalNodes = 0,
    this.totalEncounters = 0,
    this.relayNodeCount = 0,
    this.ghostNodeCount = 0,
    this.unknownNodeCount = 0,
    this.beaconNodeCount = 0,
    this.averagePatinaScore = 0.0,
    this.regionCount = 0,
  });

  /// Empty metrics — no mesh data available.
  static const empty = MeshAtmosphereMetrics();

  /// Fraction of nodes classified as relay (0.0–1.0).
  double get relayFraction =>
      totalNodes > 0 ? relayNodeCount / totalNodes : 0.0;

  /// Fraction of nodes classified as ghost (0.0–1.0).
  double get ghostFraction =>
      totalNodes > 0 ? ghostNodeCount / totalNodes : 0.0;

  /// Fraction of nodes classified as unknown (0.0–1.0).
  double get unknownFraction =>
      totalNodes > 0 ? unknownNodeCount / totalNodes : 0.0;

  /// Combined "sparse data" fraction — ghost + unknown nodes.
  double get sparseFraction =>
      totalNodes > 0 ? (ghostNodeCount + unknownNodeCount) / totalNodes : 0.0;

  /// Average encounters per node.
  double get encountersPerNode =>
      totalNodes > 0 ? totalEncounters / totalNodes : 0.0;
}

/// Pure-function engine that converts mesh metrics to atmosphere intensities.
///
/// All methods are static. No state, no side effects, no async.
/// The same [MeshAtmosphereMetrics] always produces the same
/// [AtmosphereIntensities].
///
/// The adapter uses asymptotic curves (logarithmic saturation) so that:
///   - A mesh with 3 nodes produces noticeable but gentle effects
///   - A mesh with 50 nodes produces strong but not overwhelming effects
///   - A mesh with 500 nodes does not look much different from 50
///
/// This prevents the atmosphere from becoming visually noisy on
/// large, active networks while still providing meaningful feedback
/// on smaller meshes.
class AtmosphereDataAdapter {
  AtmosphereDataAdapter._();

  /// Compute atmosphere intensities from current mesh metrics.
  ///
  /// Returns an [AtmosphereIntensities] snapshot with values clamped
  /// between the configured floor and ceiling for each effect type.
  /// If [metrics] represents an empty mesh (zero nodes), returns
  /// [AtmosphereIntensities.zero].
  static AtmosphereIntensities compute(MeshAtmosphereMetrics metrics) {
    if (metrics.totalNodes == 0) return AtmosphereIntensities.zero;

    return AtmosphereIntensities(
      rain: _computeRain(metrics),
      ember: _computeEmber(metrics),
      mist: _computeMist(metrics),
      starlight: _computeStarlight(metrics),
    );
  }

  /// Collect metrics from NodeDex stats and trait distribution.
  ///
  /// Convenience method that extracts the relevant values from
  /// the stats object and trait distribution map. This avoids
  /// spreading the extraction logic across multiple providers.
  static MeshAtmosphereMetrics metricsFromStats({
    required int totalNodes,
    required int totalEncounters,
    required int totalRegions,
    required Map<NodeTrait, int> traitDistribution,
    required double averagePatinaScore,
  }) {
    return MeshAtmosphereMetrics(
      totalNodes: totalNodes,
      totalEncounters: totalEncounters,
      relayNodeCount: traitDistribution[NodeTrait.relay] ?? 0,
      ghostNodeCount: traitDistribution[NodeTrait.ghost] ?? 0,
      unknownNodeCount: traitDistribution[NodeTrait.unknown] ?? 0,
      beaconNodeCount: traitDistribution[NodeTrait.beacon] ?? 0,
      averagePatinaScore: averagePatinaScore,
      regionCount: totalRegions,
    );
  }

  // ---------------------------------------------------------------------------
  // Per-effect computation
  // ---------------------------------------------------------------------------

  /// Compute rain intensity from node count and encounter activity.
  ///
  /// Rain represents data flowing through the mesh. More nodes and
  /// more encounters produce denser rainfall.
  ///
  /// Curve: logarithmic saturation.
  ///   - 3 nodes: ~25% intensity
  ///   - 10 nodes: ~50% intensity
  ///   - 50 nodes: ~90% intensity
  ///   - 100+ nodes: ~95% (ceiling)
  static double _computeRain(MeshAtmosphereMetrics metrics) {
    // Primary driver: total node count.
    final nodeScore = _logSaturate(
      metrics.totalNodes.toDouble(),
      AtmosphereIntensity.rainNodeCountSaturation.toDouble(),
    );

    // Secondary driver: encounter density (encounters per node).
    // A network with high encounter rates gets slightly more rain.
    final encounterBoost =
        _logSaturate(
          metrics.encountersPerNode,
          20.0, // 20 encounters/node = full boost
        ) *
        0.3; // boost contributes 30% of the signal

    final raw = (nodeScore * 0.7 + encounterBoost).clamp(0.0, 1.0);

    return _applyFloorCeiling(
      raw,
      AtmosphereIntensity.rainFloor,
      AtmosphereIntensity.rainCeiling,
    );
  }

  /// Compute ember intensity from patina scores and relay contribution.
  ///
  /// Embers represent accumulated effort and contribution. Networks
  /// with well-documented nodes (high patina) and active relays
  /// (high relay fraction) glow warmer with rising sparks.
  ///
  /// Curve: linear blend of two asymptotic inputs.
  ///   - Average patina 20: ~30% intensity
  ///   - Average patina 50: ~60% intensity
  ///   - Average patina 80+: ~85% intensity
  ///   - Relay fraction adds up to 30% bonus
  static double _computeEmber(MeshAtmosphereMetrics metrics) {
    // Primary driver: average patina score (0-100).
    final patinaScore = _logSaturate(
      metrics.averagePatinaScore,
      AtmosphereIntensity.emberPatinaSaturation,
    );

    // Secondary driver: relay node fraction.
    final relayBoost =
        _logSaturate(
          metrics.relayFraction,
          AtmosphereIntensity.emberRelayFractionSaturation,
        ) *
        0.3;

    // Tertiary: beacon nodes add a small warmth bonus.
    final beaconFraction = metrics.totalNodes > 0
        ? metrics.beaconNodeCount / metrics.totalNodes
        : 0.0;
    final beaconBoost = _logSaturate(beaconFraction, 0.2) * 0.1;

    final raw = (patinaScore * 0.6 + relayBoost + beaconBoost).clamp(0.0, 1.0);

    return _applyFloorCeiling(
      raw,
      AtmosphereIntensity.emberFloor,
      AtmosphereIntensity.emberCeiling,
    );
  }

  /// Compute mist intensity from sparse data regions.
  ///
  /// Mist represents the unknown — nodes that are poorly documented,
  /// rarely seen, or too new to classify. A mesh full of ghosts and
  /// newcomers is shrouded in fog. As the user explores and documents
  /// their mesh, the fog lifts.
  ///
  /// Curve: linear from sparse fraction.
  ///   - 10% sparse nodes: light mist
  ///   - 30% sparse nodes: moderate fog
  ///   - 50%+ sparse nodes: heavy fog (ceiling)
  static double _computeMist(MeshAtmosphereMetrics metrics) {
    // Primary driver: fraction of ghost + unknown nodes.
    final sparseScore = _logSaturate(
      metrics.sparseFraction,
      AtmosphereIntensity.mistSparseFractionSaturation,
    );

    // Inverse relationship with patina — high average patina
    // reduces mist because the mesh is well-documented.
    final patinaReduction =
        _logSaturate(metrics.averagePatinaScore / 100.0, 0.5) * 0.3;

    final raw = (sparseScore - patinaReduction).clamp(0.0, 1.0);

    return _applyFloorCeiling(
      raw,
      AtmosphereIntensity.mistFloor,
      AtmosphereIntensity.mistCeiling,
    );
  }

  /// Compute starlight intensity.
  ///
  /// Starlight is the ambient baseline — always gently present
  /// when the atmosphere system is enabled. It scales mildly with
  /// total node count so that larger meshes have a slightly richer
  /// starfield, but the effect is never zero (even an empty mesh
  /// gets the floor level).
  ///
  /// Curve: gentle logarithmic with high floor.
  ///   - 0 nodes: floor (15%)
  ///   - 5 nodes: ~22% intensity
  ///   - 20 nodes: ~30% intensity
  ///   - 100+ nodes: ~40% (ceiling)
  static double _computeStarlight(MeshAtmosphereMetrics metrics) {
    // Very gentle scaling from node count.
    final nodeScore = _logSaturate(
      metrics.totalNodes.toDouble(),
      100.0, // saturates slowly
    );

    // Region diversity adds a small bonus — more explored = more stars.
    final regionBonus =
        _logSaturate(metrics.regionCount.toDouble(), 10.0) * 0.15;

    final raw = (nodeScore * 0.6 + regionBonus).clamp(0.0, 1.0);

    return _applyFloorCeiling(
      raw,
      AtmosphereIntensity.starlightFloor,
      AtmosphereIntensity.starlightCeiling,
    );
  }

  // ---------------------------------------------------------------------------
  // Utility functions
  // ---------------------------------------------------------------------------

  /// Logarithmic saturation curve.
  ///
  /// Maps [value] to the range 0.0–1.0 using the curve:
  ///   score = ln(1 + value) / ln(1 + saturation)
  ///
  /// This produces fast initial gains that taper off as [value]
  /// approaches [saturation]. Values above saturation are clamped
  /// to 1.0.
  ///
  /// Examples (with saturation = 50):
  ///   - value  1: 0.17
  ///   - value  5: 0.46
  ///   - value 10: 0.61
  ///   - value 25: 0.82
  ///   - value 50: 1.00
  static double _logSaturate(double value, double saturation) {
    if (value <= 0 || saturation <= 0) return 0.0;
    return (math.log(1.0 + value) / math.log(1.0 + saturation)).clamp(0.0, 1.0);
  }

  /// Apply floor and ceiling to a raw 0.0–1.0 intensity value.
  ///
  /// If [raw] is zero, returns zero (effect is completely off).
  /// Otherwise, maps the raw value to the range [floor, ceiling].
  static double _applyFloorCeiling(double raw, double floor, double ceiling) {
    if (raw <= 0) return 0.0;
    return (floor + raw * (ceiling - floor)).clamp(0.0, 1.0);
  }
}
