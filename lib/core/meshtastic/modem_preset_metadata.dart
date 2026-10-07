// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Centralized ModemPreset metadata. One row per Meshtastic
// `Config_LoRaConfig_ModemPreset`. The radio_config_screen modem
// preset selector reads from [kModemPresetMetadata]. Adding a new
// preset is one entry plus one ARB key per locale — no per-screen
// edits. Mirrors the Apple iOS app's `enum ModemPresets:
// CaseIterable` from
// `meshtastic-ios/Meshtastic/Enums/LoraConfigEnums.swift`.

import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import 'region_metadata.dart' show LocalizedStringFn;

class ModemPresetMetadata {
  const ModemPresetMetadata({
    required this.preset,
    required this.label,
    required this.description,
    required this.bandwidthKhz,
  });

  final config_pbenum.Config_LoRaConfig_ModemPreset preset;
  final LocalizedStringFn label;
  final LocalizedStringFn description;

  /// Channel bandwidth the firmware runs this preset at outside the
  /// 2.4 GHz wide-LoRa region (`modemPresetToParams` in MeshRadio.h).
  final double bandwidthKhz;
}

// Ordered as they appear in the picker — protobuf-numeric except for
// VERY_LONG_SLOW (deprecated upstream in 2.5 but still surfaced for
// users who already have it set; iOS hides it entirely).
final List<ModemPresetMetadata> kModemPresetMetadata = <ModemPresetMetadata>[
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
    label: (l) => l.radioConfigPresetLongFast,
    description: (l) => l.radioConfigPresetLongFastDesc,
    bandwidthKhz: 250,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_SLOW,
    label: (l) => l.radioConfigPresetLongSlow,
    description: (l) => l.radioConfigPresetLongSlowDesc,
    bandwidthKhz: 125,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.VERY_LONG_SLOW,
    label: (l) => l.radioConfigPresetVeryLongSlow,
    description: (l) => l.radioConfigPresetVeryLongSlowDesc,
    // No longer a firmware case: it falls through to Long Fast's params.
    bandwidthKhz: 250,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE,
    label: (l) => l.radioConfigPresetLongModerate,
    description: (l) => l.radioConfigPresetLongModerateDesc,
    bandwidthKhz: 125,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
    label: (l) => l.radioConfigPresetMediumFast,
    description: (l) => l.radioConfigPresetMediumFastDesc,
    bandwidthKhz: 250,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_SLOW,
    label: (l) => l.radioConfigPresetMediumSlow,
    description: (l) => l.radioConfigPresetMediumSlowDesc,
    bandwidthKhz: 250,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST,
    label: (l) => l.radioConfigPresetShortFast,
    description: (l) => l.radioConfigPresetShortFastDesc,
    bandwidthKhz: 250,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_SLOW,
    label: (l) => l.radioConfigPresetShortSlow,
    description: (l) => l.radioConfigPresetShortSlowDesc,
    bandwidthKhz: 250,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_TURBO,
    label: (l) => l.radioConfigPresetShortTurbo,
    description: (l) => l.radioConfigPresetShortTurboDesc,
    bandwidthKhz: 500,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO,
    label: (l) => l.radioConfigPresetLongTurbo,
    description: (l) => l.radioConfigPresetLongTurboDesc,
    bandwidthKhz: 500,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LITE_FAST,
    label: (l) => l.radioConfigPresetLiteFast,
    description: (l) => l.radioConfigPresetLiteFastDesc,
    bandwidthKhz: 125,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LITE_SLOW,
    label: (l) => l.radioConfigPresetLiteSlow,
    description: (l) => l.radioConfigPresetLiteSlowDesc,
    bandwidthKhz: 125,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.NARROW_FAST,
    label: (l) => l.radioConfigPresetNarrowFast,
    description: (l) => l.radioConfigPresetNarrowFastDesc,
    bandwidthKhz: 62.5,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.NARROW_SLOW,
    label: (l) => l.radioConfigPresetNarrowSlow,
    description: (l) => l.radioConfigPresetNarrowSlowDesc,
    bandwidthKhz: 62.5,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.TINY_FAST,
    label: (l) => l.radioConfigPresetTinyFast,
    description: (l) => l.radioConfigPresetTinyFastDesc,
    bandwidthKhz: 15.6,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.TINY_SLOW,
    label: (l) => l.radioConfigPresetTinySlow,
    description: (l) => l.radioConfigPresetTinySlowDesc,
    bandwidthKhz: 15.6,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_TURBO,
    label: (l) => l.radioConfigPresetMediumTurbo,
    description: (l) => l.radioConfigPresetMediumTurboDesc,
    bandwidthKhz: 500,
  ),
];

final Map<config_pbenum.Config_LoRaConfig_ModemPreset, ModemPresetMetadata>
_presetByEnum = {for (final p in kModemPresetMetadata) p.preset: p};

ModemPresetMetadata? modemPresetMetadataFor(
  config_pbenum.Config_LoRaConfig_ModemPreset preset,
) => _presetByEnum[preset];

/// True when [region] is US and the radio would run narrower than 500 kHz,
/// the minimum 6 dB bandwidth FCC Part 15.247 sets for digital modulation
/// in 902-928 MHz. Other US rule paths (frequency hopping, 15.249, amateur
/// operation) do not carry that minimum, so this marks a configuration for
/// the user to review; it does not judge it.
///
/// [customBandwidthCode] is `Config_LoRaConfig.bandwidth`, read only when
/// [usePreset] is false. 0 is the firmware default of 250 kHz, and 31 and
/// 62 encode 31.25 and 62.5 kHz, so every code below 500 is narrower.
bool isUsBelow500KhzBandwidth({
  required config_pbenum.Config_LoRaConfig_RegionCode? region,
  required bool usePreset,
  required config_pbenum.Config_LoRaConfig_ModemPreset? preset,
  required int customBandwidthCode,
}) {
  if (region != config_pbenum.Config_LoRaConfig_RegionCode.US) return false;
  if (!usePreset) return customBandwidthCode < 500;
  if (preset == null) return false;
  final metadata = modemPresetMetadataFor(preset);
  return metadata != null && metadata.bandwidthKhz < 500;
}
