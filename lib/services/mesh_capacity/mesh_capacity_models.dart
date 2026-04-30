// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh Capacity Advisor domain models.
//
// The advisor inspects the locally observed mesh — recently-heard RF nodes
// and the device's current modem preset — and produces a deterministic
// snapshot describing how saturated the airtime is for the active preset.
// It never mutates radio state. It produces an advisory recommendation
// that the UI surfaces as a card.

import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;

/// Pressure level of the local mesh relative to the active preset.
enum MeshCapacityPressureLevel {
  /// Snapshot is missing too much data to assess (no preset, no nodes,
  /// or device disconnected).
  unknown,

  /// Mesh is comfortably under the preset's capacity envelope.
  healthy,

  /// Mesh is starting to fill up — informational, no advisory needed.
  busy,

  /// Mesh is dense for the active preset — advisory card recommended.
  congested,

  /// Mesh is at or beyond the preset's safe capacity for reliable
  /// delivery — strong advisory.
  capacityLimited,
}

/// Severity of a recommendation, used to drive the card's visual weight.
enum MeshCapacityRecommendationSeverity { none, info, advisory, warning }

/// Stable, deterministic reason code for telemetry and copy selection.
enum MeshCapacityReasonCode {
  /// Not enough data to assess (no preset, no recent RF evidence, or
  /// device disconnected).
  insufficientData,

  /// We have node evidence but the active modem preset is not known.
  presetUnknown,

  /// Active preset is healthy for the observed density.
  healthyForPreset,

  /// Mesh is moderately busy but the preset is acceptable.
  busyButAcceptable,

  /// Long-range preset (LONG_FAST / LONG_SLOW / LONG_MODERATE /
  /// LONG_TURBO / VERY_LONG_SLOW) in a dense local mesh.
  longPresetDenseMesh,

  /// Medium-range preset in a dense local mesh.
  slowPresetDenseMesh,

  /// Density is event-scale — only ShortFast/Turbo can sustain it.
  veryDenseEventLikeMesh,
}

/// Recommendation produced by the advisor. May be empty (no card) when
/// the mesh is healthy for the active preset.
class MeshCapacityRecommendation {
  const MeshCapacityRecommendation({
    required this.severity,
    required this.reasonCode,
    required this.shouldShowCard,
    this.suggestedPreset,
  });

  /// Empty recommendation — no card, healthy state.
  const MeshCapacityRecommendation.none()
    : severity = MeshCapacityRecommendationSeverity.none,
      reasonCode = MeshCapacityReasonCode.healthyForPreset,
      shouldShowCard = false,
      suggestedPreset = null;

  final MeshCapacityRecommendationSeverity severity;
  final MeshCapacityReasonCode reasonCode;

  /// Whether the card should be rendered. The advisor may decide to
  /// suppress display even when a recommendation exists (e.g. healthy).
  final bool shouldShowCard;

  /// Concrete preset suggested when one is appropriate. `null` when the
  /// advisor cannot or should not name a specific preset.
  final config_pbenum.Config_LoRaConfig_ModemPreset? suggestedPreset;
}

/// Snapshot of the local mesh's capacity state for the active preset.
///
/// This is a pure value object. It is regenerated whenever the inputs
/// (nodes / modem preset) change. It is the single artifact the UI
/// consumes — there is no separate "current preset" or "node count"
/// for the advisor card.
class MeshCapacitySnapshot {
  const MeshCapacitySnapshot({
    required this.activeRfNodes5m,
    required this.activeRfNodes15m,
    required this.activeRfNodes60m,
    required this.totalKnownNodes,
    required this.currentModemPreset,
    required this.currentChannelName,
    required this.hasPresetInfo,
    required this.hasSufficientSignalData,
    required this.pressureLevel,
    required this.recommendation,
    required this.generatedAt,
    this.recentPacketRatePerMinute,
    this.duplicatePacketRate,
  });

  /// Empty snapshot — used before the device is connected or any
  /// nodes have been observed.
  factory MeshCapacitySnapshot.empty(DateTime now) => MeshCapacitySnapshot(
    activeRfNodes5m: 0,
    activeRfNodes15m: 0,
    activeRfNodes60m: 0,
    totalKnownNodes: 0,
    currentModemPreset: null,
    currentChannelName: null,
    hasPresetInfo: false,
    hasSufficientSignalData: false,
    pressureLevel: MeshCapacityPressureLevel.unknown,
    recommendation: const MeshCapacityRecommendation(
      severity: MeshCapacityRecommendationSeverity.none,
      reasonCode: MeshCapacityReasonCode.insufficientData,
      shouldShowCard: false,
    ),
    generatedAt: now,
  );

  /// RF-heard nodes in the last 5 minutes (excludes self + MQTT-only).
  final int activeRfNodes5m;

  /// RF-heard nodes in the last 15 minutes (the primary signal).
  final int activeRfNodes15m;

  /// RF-heard nodes in the last 60 minutes (longer baseline).
  final int activeRfNodes60m;

  /// Total entries in the local NodeDB regardless of recency or transport.
  final int totalKnownNodes;

  /// Currently active modem preset, if known. `null` when the device has
  /// not advertised LoRa config yet.
  final config_pbenum.Config_LoRaConfig_ModemPreset? currentModemPreset;

  /// Primary-channel name if available. Display-only; not used for
  /// thresholding.
  final String? currentChannelName;

  /// Whether the snapshot has a definitive modem preset. When `false`,
  /// the advisor will not recommend a concrete suggested preset.
  final bool hasPresetInfo;

  /// Whether enough signal evidence exists to make a meaningful
  /// recommendation. Currently means: at least one node has a non-null
  /// `lastHeard` within the 60-minute window. This is the cleanest
  /// approximation available without a packet-history database — see
  /// docs/architecture/MESH_RULES.md and the advisor unit tests for the
  /// exact rule.
  final bool hasSufficientSignalData;

  final MeshCapacityPressureLevel pressureLevel;
  final MeshCapacityRecommendation recommendation;
  final DateTime generatedAt;

  /// Packet rate observed in the recent past, packets/min. v1 leaves
  /// this unset because the app does not currently maintain a low-cost
  /// packet history surface; advisor decisions are based on active RF
  /// node density only.
  final double? recentPacketRatePerMinute;

  /// Approximate duplicate packet rate (0..1). v1 unset for the same
  /// reason as [recentPacketRatePerMinute].
  final double? duplicatePacketRate;
}
