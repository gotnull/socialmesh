// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh Capacity Advisor — pure deterministic logic.
//
// No Flutter widget imports. No provider reads. No I/O. Given the inputs
// (recently-heard RF nodes + active modem preset + clock), this returns
// a [MeshCapacitySnapshot] with a deterministic recommendation. The
// thresholds are explicit constants and exhaustively covered by unit
// tests in test/services/mesh_capacity/mesh_capacity_advisor_test.dart.
//
// "Recently-heard RF nodes" means: nodes the local device has observed
// directly over the radio (not MQTT-bridged), with a `lastHeard`
// timestamp inside the relevant window, excluding self.

import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../models/mesh_models.dart';
import 'mesh_capacity_models.dart';

/// Per-preset density thresholds. Numbers represent the count of
/// distinct RF-active nodes seen in the last 15 minutes that pushes the
/// mesh into each pressure level for that preset.
///
/// The defaults below are the v1 spec values. They are intentionally
/// conservative — long-range presets fill airtime quickly because each
/// packet costs more on-air time, so the advisory thresholds are low.
/// Faster presets tolerate far more density before delivery degrades.
class MeshCapacityThresholds {
  const MeshCapacityThresholds({
    required this.busy,
    required this.congested,
    required this.capacityLimited,
  });

  final int busy;
  final int congested;
  final int capacityLimited;
}

class MeshCapacityAdvisor {
  const MeshCapacityAdvisor();

  static const Duration _window5m = Duration(minutes: 5);
  static const Duration _window15m = Duration(minutes: 15);
  static const Duration _window60m = Duration(minutes: 60);

  /// Per-preset density thresholds. Mirrors the v1 spec exactly. Any
  /// preset not listed here falls through to [_unknownPresetThresholds]
  /// and the advisor will not recommend a concrete suggested preset.
  static final Map<
    config_pbenum.Config_LoRaConfig_ModemPreset,
    MeshCapacityThresholds
  >
  _thresholds = {
    config_pbenum.Config_LoRaConfig_ModemPreset.LONG_SLOW:
        const MeshCapacityThresholds(
          busy: 10,
          congested: 20,
          capacityLimited: 40,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.VERY_LONG_SLOW:
        const MeshCapacityThresholds(
          busy: 10,
          congested: 20,
          capacityLimited: 40,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE:
        const MeshCapacityThresholds(
          busy: 15,
          congested: 30,
          capacityLimited: 55,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST:
        const MeshCapacityThresholds(
          busy: 25,
          congested: 40,
          capacityLimited: 70,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO:
        const MeshCapacityThresholds(
          busy: 25,
          congested: 40,
          capacityLimited: 70,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_SLOW:
        const MeshCapacityThresholds(
          busy: 60,
          congested: 100,
          capacityLimited: 200,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST:
        const MeshCapacityThresholds(
          busy: 60,
          congested: 100,
          capacityLimited: 200,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_SLOW:
        const MeshCapacityThresholds(
          busy: 150,
          congested: 250,
          capacityLimited: 500,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST:
        const MeshCapacityThresholds(
          busy: 150,
          congested: 250,
          capacityLimited: 500,
        ),
    config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_TURBO:
        const MeshCapacityThresholds(
          busy: 300,
          congested: 500,
          capacityLimited: 1000,
        ),
  };

  /// Generate a snapshot. Pure function of its inputs.
  ///
  /// [nodes] is the live NodeDB map. [myNodeNum] is excluded from RF
  /// density counts to avoid self-counting. [preset] may be `null` when
  /// the device has not advertised LoRa config yet — in that case the
  /// advisor degrades gracefully and produces a `presetUnknown`
  /// recommendation rather than guessing.
  MeshCapacitySnapshot evaluate({
    required Iterable<MeshNode> nodes,
    required int? myNodeNum,
    required config_pbenum.Config_LoRaConfig_ModemPreset? preset,
    required DateTime now,
    String? currentChannelName,
  }) {
    final allNodes = nodes.toList(growable: false);
    final totalKnown = allNodes.length;

    var rf5m = 0;
    var rf15m = 0;
    var rf60m = 0;
    var anyRecentRf = false;

    for (final node in allNodes) {
      if (myNodeNum != null && node.nodeNum == myNodeNum) continue;
      if (node.viaMqtt) continue;
      final last = node.lastHeard;
      if (last == null) continue;
      final age = now.difference(last);
      if (age.isNegative) continue;
      if (age <= _window60m) {
        anyRecentRf = true;
        rf60m++;
        if (age <= _window15m) rf15m++;
        if (age <= _window5m) rf5m++;
      }
    }

    final hasPreset = preset != null && _thresholds.containsKey(preset);
    // Sufficient signal data = at least one RF-heard node inside the
    // 60-minute window. Without this we cannot reason about density at
    // all. Document carefully here because v1 does not yet incorporate
    // packet-rate evidence.
    final hasSignal = anyRecentRf;

    if (!hasSignal) {
      return MeshCapacitySnapshot(
        activeRfNodes5m: rf5m,
        activeRfNodes15m: rf15m,
        activeRfNodes60m: rf60m,
        totalKnownNodes: totalKnown,
        currentModemPreset: preset,
        currentChannelName: currentChannelName,
        hasPresetInfo: hasPreset,
        hasSufficientSignalData: false,
        pressureLevel: MeshCapacityPressureLevel.unknown,
        recommendation: const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.none,
          reasonCode: MeshCapacityReasonCode.insufficientData,
          shouldShowCard: false,
        ),
        generatedAt: now,
      );
    }

    if (!hasPreset) {
      return MeshCapacitySnapshot(
        activeRfNodes5m: rf5m,
        activeRfNodes15m: rf15m,
        activeRfNodes60m: rf60m,
        totalKnownNodes: totalKnown,
        currentModemPreset: preset,
        currentChannelName: currentChannelName,
        hasPresetInfo: false,
        hasSufficientSignalData: true,
        pressureLevel: MeshCapacityPressureLevel.unknown,
        recommendation: const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.info,
          reasonCode: MeshCapacityReasonCode.presetUnknown,
          shouldShowCard: true,
        ),
        generatedAt: now,
      );
    }

    final thresholds = _thresholds[preset]!;
    final pressure = _pressureFor(rf15m, thresholds);
    final recommendation = _recommendationFor(
      preset: preset,
      pressure: pressure,
      rf15m: rf15m,
    );

    return MeshCapacitySnapshot(
      activeRfNodes5m: rf5m,
      activeRfNodes15m: rf15m,
      activeRfNodes60m: rf60m,
      totalKnownNodes: totalKnown,
      currentModemPreset: preset,
      currentChannelName: currentChannelName,
      hasPresetInfo: true,
      hasSufficientSignalData: true,
      pressureLevel: pressure,
      recommendation: recommendation,
      generatedAt: now,
    );
  }

  MeshCapacityPressureLevel _pressureFor(int rf15m, MeshCapacityThresholds t) {
    if (rf15m >= t.capacityLimited) {
      return MeshCapacityPressureLevel.capacityLimited;
    }
    if (rf15m >= t.congested) return MeshCapacityPressureLevel.congested;
    if (rf15m >= t.busy) return MeshCapacityPressureLevel.busy;
    return MeshCapacityPressureLevel.healthy;
  }

  MeshCapacityRecommendation _recommendationFor({
    required config_pbenum.Config_LoRaConfig_ModemPreset preset,
    required MeshCapacityPressureLevel pressure,
    required int rf15m,
  }) {
    final isLong = _isLongPreset(preset);
    final isMedium = _isMediumPreset(preset);
    final isShort = _isShortPreset(preset);

    switch (pressure) {
      case MeshCapacityPressureLevel.healthy:
        return const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.none,
          reasonCode: MeshCapacityReasonCode.healthyForPreset,
          shouldShowCard: false,
        );
      case MeshCapacityPressureLevel.busy:
        return const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.info,
          reasonCode: MeshCapacityReasonCode.busyButAcceptable,
          shouldShowCard: true,
        );
      case MeshCapacityPressureLevel.congested:
        if (isLong) {
          return MeshCapacityRecommendation(
            severity: MeshCapacityRecommendationSeverity.advisory,
            reasonCode: MeshCapacityReasonCode.longPresetDenseMesh,
            shouldShowCard: true,
            suggestedPreset:
                config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
          );
        }
        if (isMedium) {
          return MeshCapacityRecommendation(
            severity: MeshCapacityRecommendationSeverity.advisory,
            reasonCode: MeshCapacityReasonCode.slowPresetDenseMesh,
            shouldShowCard: true,
            suggestedPreset:
                config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST,
          );
        }
        // Short presets at congested levels are unusual — surface as
        // event-like density rather than nagging about a preset change.
        return const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.advisory,
          reasonCode: MeshCapacityReasonCode.veryDenseEventLikeMesh,
          shouldShowCard: true,
        );
      case MeshCapacityPressureLevel.capacityLimited:
        if (isLong) {
          // For very dense (event-style) density on a long preset the
          // suggestion escalates to ShortFast. ShortTurbo is reserved
          // for explicitly intentional dense / short-range networks
          // and is never recommended casually.
          return MeshCapacityRecommendation(
            severity: MeshCapacityRecommendationSeverity.warning,
            reasonCode: MeshCapacityReasonCode.longPresetDenseMesh,
            shouldShowCard: true,
            suggestedPreset:
                config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST,
          );
        }
        if (isMedium) {
          return MeshCapacityRecommendation(
            severity: MeshCapacityRecommendationSeverity.warning,
            reasonCode: MeshCapacityReasonCode.slowPresetDenseMesh,
            shouldShowCard: true,
            suggestedPreset:
                config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST,
          );
        }
        if (isShort) {
          // Already on a short preset and still saturated — surface as
          // event-like density, no concrete preset suggestion.
          return const MeshCapacityRecommendation(
            severity: MeshCapacityRecommendationSeverity.warning,
            reasonCode: MeshCapacityReasonCode.veryDenseEventLikeMesh,
            shouldShowCard: true,
          );
        }
        return const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.warning,
          reasonCode: MeshCapacityReasonCode.veryDenseEventLikeMesh,
          shouldShowCard: true,
        );
      case MeshCapacityPressureLevel.unknown:
        return const MeshCapacityRecommendation(
          severity: MeshCapacityRecommendationSeverity.none,
          reasonCode: MeshCapacityReasonCode.insufficientData,
          shouldShowCard: false,
        );
    }
  }

  bool _isLongPreset(config_pbenum.Config_LoRaConfig_ModemPreset p) {
    return p == config_pbenum.Config_LoRaConfig_ModemPreset.LONG_SLOW ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.VERY_LONG_SLOW;
  }

  bool _isMediumPreset(config_pbenum.Config_LoRaConfig_ModemPreset p) {
    return p == config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_SLOW ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST;
  }

  bool _isShortPreset(config_pbenum.Config_LoRaConfig_ModemPreset p) {
    return p == config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_SLOW ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST ||
        p == config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_TURBO;
  }
}
