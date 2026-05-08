// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Radio Compatibility Helper — pure derivation of a NodeDex entry's
// reachability status from local LoRa config + persisted observation
// metadata + live MeshNode fallback.
//
// HONEST FRAMING: Meshtastic firmware does not broadcast a remote node's
// region / modem preset / frequency slot in NodeInfo, User, or MeshPacket.
// All "preset comparison" surfaces compare *the local radio's preset when
// we last heard the node* against *the local radio's preset right now*.
// We never claim to know the remote's preset.

import '../../../generated/meshtastic/config.pb.dart' as config_pb;
import '../models/nodedex_entry.dart';
import '../models/observation_source.dart';

/// Reachability classification surfaced on the NodeDex detail screen.
///
/// Decision order is encoded in [evaluateRadioCompatibility]; values
/// earlier in the order short-circuit later checks.
enum NodeDexReachabilityStatus {
  /// Local preset matches the preset that was active when the node was
  /// last observed; the latest observation came in over direct RF; hops
  /// is 0. Hedged with "Likely" in the UI because real reachability also
  /// depends on airtime, SNR, node state, encryption, and topology.
  likelyReachableOnRf,

  /// The local radio is on a different preset than when this node was
  /// last observed.
  differentPreset,

  /// Same preset, but the local frequency offset differs from the offset
  /// active when the node was last observed.
  differentFrequencyOffset,

  /// Latest observation arrived via MQTT, or with hops > 0. Describes the
  /// latest observation, not a permanent reachability claim — the node
  /// may still be directly reachable later, or may have been before.
  indirectOrMqttObservation,

  /// No local radio is connected; comparison is impossible. Persisted
  /// observation rows still render, only the reachability row swaps.
  localRadioUnknown,

  /// Insufficient data to classify (e.g. no preset recorded for the
  /// observation and no live fallback).
  unknown,

  /// The node *is* the local radio. The Radio Compatibility card is
  /// hidden in this case.
  selfNode,
}

/// Live-MeshNode fields used as a fallback when the entry has not yet
/// persisted observation context. Pulled from the [MeshNode] model at
/// the call site; this helper is pure and never imports MeshNode itself
/// to keep tests free of widget plumbing.
class LiveObservationFallback {
  /// Whether the live node was discovered via an MQTT bridge.
  /// Source: `MeshNode.viaMqtt`.
  final bool viaMqtt;

  /// Hops away from the local radio. 0 = direct, >0 = relayed.
  /// Source: `MeshNode.hopCount` (which mirrors `NodeInfo.hopsAway`).
  final int? hopCount;

  const LiveObservationFallback({required this.viaMqtt, this.hopCount});
}

/// Derived summary of a node's radio compatibility, ready for UI rendering.
class NodeDexRadioCompatibilitySummary {
  final NodeDexReachabilityStatus status;

  /// Local radio's modem preset right now (protobuf int value).
  /// Null when no radio is connected.
  final int? localPresetNow;

  /// Local radio's frequency offset right now in Hz.
  /// Null when no radio is connected or the offset is zero.
  final double? localFrequencyOffsetNow;

  /// The local preset that was active when the node was last observed.
  /// Null for legacy entries where the preset wasn't recorded.
  final int? lastObservedOnPreset;

  /// The local frequency offset that was active when the node was last
  /// observed, in Hz. Null for legacy entries or zero offset.
  final double? lastObservedFrequencyOffset;

  /// Effective observation source — either the persisted value on the
  /// entry or the live-MeshNode fallback. Null only when neither is
  /// available.
  final ObservationSource? observationSource;

  /// Effective hop count — either persisted on the entry or from the
  /// live MeshNode. Null when neither is available.
  final int? hopsAway;

  /// True when the helper considered the node to be the user's local
  /// radio. The UI hides the entire card in this case.
  final bool isSelf;

  const NodeDexRadioCompatibilitySummary({
    required this.status,
    this.localPresetNow,
    this.localFrequencyOffsetNow,
    this.lastObservedOnPreset,
    this.lastObservedFrequencyOffset,
    this.observationSource,
    this.hopsAway,
    this.isSelf = false,
  });
}

/// Frequency-offset equality threshold in Hz. Differences below this are
/// treated as the same offset (firmware reports float precision; tiny
/// drift is not a reachability concern).
const double _kFrequencyOffsetEpsilonHz = 1.0;

/// Evaluate radio compatibility between a NodeDex entry and the local
/// radio's current LoRa config.
///
/// Decision order:
/// 1. `isSelf` → [NodeDexReachabilityStatus.selfNode].
/// 2. `localConfig == null` → [NodeDexReachabilityStatus.localRadioUnknown].
///    The summary still carries the persisted observation context so the
///    UI can keep rendering its other rows.
/// 3. Resolve `effectiveSource` = `entry.lastObservationSource ??`
///    fallback derived from the live MeshNode (`viaMqtt` → mqtt;
///    `viaMqtt = false` + `hopCount > 0` → indirectRf; etc).
/// 4. Resolve `effectiveHops` = `entry.lastHopsAway ?? liveFallback?.hopCount`.
/// 5. If `effectiveSource == mqtt` OR `effectiveHops != null && effectiveHops > 0`
///    → [NodeDexReachabilityStatus.indirectOrMqttObservation]. This
///    short-circuits even if presets match — the node may still be
///    reachable directly later, but the latest observation says "indirect".
/// 6. If `entry.lastObservedOnPreset == null` → [NodeDexReachabilityStatus.unknown].
/// 7. If `entry.lastObservedOnPreset != localConfig.modemPreset.value`
///    → [NodeDexReachabilityStatus.differentPreset].
/// 8. If presets match but
///    `(localConfig.frequencyOffset - entry.lastObservedFrequencyOffset).abs()`
///    exceeds [_kFrequencyOffsetEpsilonHz]
///    → [NodeDexReachabilityStatus.differentFrequencyOffset].
/// 9. Else → [NodeDexReachabilityStatus.likelyReachableOnRf].
NodeDexRadioCompatibilitySummary evaluateRadioCompatibility({
  required NodeDexEntry entry,
  required config_pb.Config_LoRaConfig? localConfig,
  required bool isSelf,
  LiveObservationFallback? liveFallback,
}) {
  // 1. Self node: hide the card entirely.
  if (isSelf) {
    return NodeDexRadioCompatibilitySummary(
      status: NodeDexReachabilityStatus.selfNode,
      isSelf: true,
      lastObservedOnPreset: entry.lastObservedOnPreset,
      lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
      observationSource: entry.lastObservationSource,
      hopsAway: entry.lastHopsAway,
    );
  }

  // 3-4. Resolve effective observation context with live-MeshNode fallback.
  final effectiveSource =
      entry.lastObservationSource ?? _fallbackSource(liveFallback);
  final effectiveHops = entry.lastHopsAway ?? liveFallback?.hopCount;

  // 2. No local radio: skip comparison but keep persisted rows.
  if (localConfig == null) {
    return NodeDexRadioCompatibilitySummary(
      status: NodeDexReachabilityStatus.localRadioUnknown,
      lastObservedOnPreset: entry.lastObservedOnPreset,
      lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
      observationSource: effectiveSource,
      hopsAway: effectiveHops,
    );
  }

  final localPresetNow = localConfig.modemPreset.value;
  final localFreqOffsetNow = localConfig.frequencyOffset == 0.0
      ? null
      : localConfig.frequencyOffset;

  // 5. Indirect / MQTT observation short-circuits preset comparison.
  if (effectiveSource == ObservationSource.mqtt ||
      (effectiveHops != null && effectiveHops > 0)) {
    return NodeDexRadioCompatibilitySummary(
      status: NodeDexReachabilityStatus.indirectOrMqttObservation,
      localPresetNow: localPresetNow,
      localFrequencyOffsetNow: localFreqOffsetNow,
      lastObservedOnPreset: entry.lastObservedOnPreset,
      lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
      observationSource: effectiveSource,
      hopsAway: effectiveHops,
    );
  }

  // 6. No persisted preset → unknown.
  if (entry.lastObservedOnPreset == null) {
    return NodeDexRadioCompatibilitySummary(
      status: NodeDexReachabilityStatus.unknown,
      localPresetNow: localPresetNow,
      localFrequencyOffsetNow: localFreqOffsetNow,
      lastObservedOnPreset: null,
      lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
      observationSource: effectiveSource,
      hopsAway: effectiveHops,
    );
  }

  // 7. Preset mismatch.
  if (entry.lastObservedOnPreset != localPresetNow) {
    return NodeDexRadioCompatibilitySummary(
      status: NodeDexReachabilityStatus.differentPreset,
      localPresetNow: localPresetNow,
      localFrequencyOffsetNow: localFreqOffsetNow,
      lastObservedOnPreset: entry.lastObservedOnPreset,
      lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
      observationSource: effectiveSource,
      hopsAway: effectiveHops,
    );
  }

  // 8. Frequency offset mismatch (only when both sides have a value).
  if (entry.lastObservedFrequencyOffset != null &&
      localFreqOffsetNow != null &&
      (localFreqOffsetNow - entry.lastObservedFrequencyOffset!).abs() >
          _kFrequencyOffsetEpsilonHz) {
    return NodeDexRadioCompatibilitySummary(
      status: NodeDexReachabilityStatus.differentFrequencyOffset,
      localPresetNow: localPresetNow,
      localFrequencyOffsetNow: localFreqOffsetNow,
      lastObservedOnPreset: entry.lastObservedOnPreset,
      lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
      observationSource: effectiveSource,
      hopsAway: effectiveHops,
    );
  }

  // 9. Everything aligned with what we know.
  return NodeDexRadioCompatibilitySummary(
    status: NodeDexReachabilityStatus.likelyReachableOnRf,
    localPresetNow: localPresetNow,
    localFrequencyOffsetNow: localFreqOffsetNow,
    lastObservedOnPreset: entry.lastObservedOnPreset,
    lastObservedFrequencyOffset: entry.lastObservedFrequencyOffset,
    observationSource: effectiveSource,
    hopsAway: effectiveHops,
  );
}

/// Derive an [ObservationSource] from live MeshNode metadata when the
/// persisted entry value is null. Mirrors the ingest-time classifier in
/// [NodeDexNotifier._resolveObservationSource] so that the live fallback
/// produces the same answer as a freshly-stamped encounter would.
ObservationSource? _fallbackSource(LiveObservationFallback? fallback) {
  if (fallback == null) return null;
  if (fallback.viaMqtt) return ObservationSource.mqtt;
  final hops = fallback.hopCount;
  if (hops == null) return ObservationSource.unknown;
  return hops > 0 ? ObservationSource.indirectRf : ObservationSource.directRf;
}
